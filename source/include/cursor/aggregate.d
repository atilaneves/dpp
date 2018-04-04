/**
   Translate aggregates
 */
module include.cursor.aggregate;

import include.from;


string[] translateStruct(in from!"clang".Cursor cursor,
                         ref from!"include.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.StructDecl);
    return translateAggregate(context, cursor, "struct");
}

string[] translateUnion(in from!"clang".Cursor cursor,
                        ref from!"include.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.UnionDecl);
    return translateAggregate(context, cursor, "union");
}

string[] translateEnum(in from!"clang".Cursor cursor,
                       ref from!"include.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.typecons: nullable;

    assert(cursor.kind == Cursor.Kind.EnumDecl);

    // Translate it twice so that C semantics are the same (global names)
    // but also have a named version for optional type correctness and
    // reflection capabilities.
    // This means that `enum Foo { foo, bar }` in C will become:
    // `enum Foo { foo, bar }` _and_ `enum { foo, bar }` in D.
    return
        translateAggregate(context, cursor, "enum") ~
        translateAggregate(context, cursor, "enum", nullable(""));
}

// not pure due to Cursor.opApply not being pure
string[] translateAggregate(
    ref from!"include.runtime.context".Context context,
    in from!"clang".Cursor cursor,
    in string keyword,
    in from!"std.typecons".Nullable!string spelling = from!"std.typecons".Nullable!string()
)
    @safe
{
    import include.cursor.unit: translate;
    import clang: Cursor;
    import std.algorithm: map;
    import std.array: array;

    // remember all aggregate declarations
    context.aggregateDeclarations[spellingOrNickname(cursor, context)] = true;

    const name = spelling.isNull ? spellingOrNickname(cursor, context) : spelling.get;
    const firstLine = keyword ~ ` ` ~ name;

    if(!cursor.isDefinition) return [firstLine ~ `;`];

    string[] lines;
    lines ~= firstLine;
    lines ~= `{`;

    foreach(member; cursor) {
        if(!member.isDefinition) continue;
        lines ~= translate(member, context).map!(a => "    " ~ a).array;
    }

    lines ~= `}`;

    return lines;
}


string[] translateField(in from!"clang".Cursor field,
                        ref from!"include.runtime.context".Context context)
    @safe
{

    import include.type: translate;
    import clang: Cursor, Type;
    import std.conv: text;
    import std.typecons: No;
    import std.array: replace;

    assert(field.kind == Cursor.Kind.FieldDecl, text("Field of wrong kind: ", field));

    // It's possible one of the fields is a pointer to a structure that isn't declared anywhere,
    // so we try and remember it here to fix it later
    if(field.type.kind == Type.Kind.Pointer && field.type.pointee.canonical.kind == Type.Kind.Record) {
        const type = field.type.pointee.canonical;
        const translatedType = translate(type, context);
        // const becomes a problem if we have to define a struct at the end of all translations.
        // See it.compile.projects.nv_alloc_ops
        enum constPrefix = "const(";
        const cleanedType = type.isConstQualified
            ? translatedType[constPrefix.length .. $-1] // unpack from const(T)
            : translatedType;
        context.fieldStructPointerSpellings[cleanedType] = true;
    }

    const type = translate(field.type, context, No.translatingFunction);
    return [text(type, " ", field.spelling.translateIdentifier, ";")];
}

private string translateIdentifier(in string spelling) @safe pure nothrow {
    import include.cursor.dlang: isKeyword;
    return spelling.isKeyword ? spelling ~ "_" : spelling;
}

// return the spelling if it exists, or our made-up nickname for it
// if not
package string spellingOrNickname(in from!"clang".Cursor cursor,
                                  ref from!"include.runtime.context".Context context)
    @safe
{

    import std.conv: text;

    static int index;

    if(cursor.spelling != "") return identifier(cursor);

    if(cursor.hash !in context.cursorNickNames) {
        auto nick = newAnonymousName;
        context.nickNames ~= nick;
        context.cursorNickNames[cursor.hash] = nick;
    }

    return context.cursorNickNames[cursor.hash];
}

private string identifier(in from!"clang".Cursor cursor) @safe pure {
    import clang: Cursor, Type;
    import std.conv: text;
    import std.algorithm: startsWith;
    import std.array: replace;

    const keyword = () {
        switch(cursor.kind) with(Cursor.Kind) {
            default: throw new Exception(text("Unknown kind ", cursor.kind, ": ", cursor));
            case StructDecl: return "struct";
            case UnionDecl: return "union";
            case EnumDecl: return "enum";
            case TypeRef:
            switch(cursor.type.canonical.kind) with(Type.Kind) {
                default: return "";
                case Record:
                    if(cursor.type.spelling.startsWith("struct ")) return "struct";
                    if(cursor.type.spelling.startsWith("union ")) return "union";
                    return "";
                case Enum: return "enum";
            }
        }
    }();

    // mimic C's different namespaces for struct, union and enum
    return keyword == "" ?
        cursor.spelling :
        keyword ~ "_" ~ cursor.spelling.replace(keyword ~ " ", "");
}

private string newAnonymousName() @safe {
    import std.conv: text;
    import core.atomic: atomicOp;
    shared static int index;
    return text("_Anonymous_", index.atomicOp!"+="(1));
}
