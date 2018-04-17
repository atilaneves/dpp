/**
   Translate aggregates
 */
module dpp.cursor.aggregate;

import dpp.from;
import std.range: isInputRange;


string[] translateStruct(in from!"clang".Cursor cursor,
                         ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.StructDecl);
    return translateAggregate(context, cursor, "struct");
}

string[] translateClass(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.typecons: Nullable, nullable;
    import std.algorithm: map, filter;
    import std.array: join;

    assert(cursor.kind == Cursor.Kind.ClassDecl || cursor.kind == Cursor.Kind.ClassTemplate);

    string translateTemplateParam(in Cursor cursor) {
        import dpp.type: translate;
        const maybeType = cursor.kind == Cursor.Kind.TemplateTypeParameter
            ? ""
            : translate(cursor.type, context) ~ " ";
        return maybeType ~ cursor.spelling;
    }

    auto templateParams = cursor
        .children
        .filter!(a => a.kind == Cursor.Kind.TemplateTypeParameter || a.kind == Cursor.Kind.NonTypeTemplateParameter)
        .map!translateTemplateParam
        ;

    const spelling = cursor.kind == Cursor.Kind.ClassTemplate
        ? nullable(cursor.spelling ~ `(` ~ templateParams.join(", ") ~ `)`)
        : Nullable!string();

    return translateAggregate(context, cursor, "class", "struct", spelling);
}

string[] translateUnion(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.UnionDecl);
    return translateAggregate(context, cursor, "union");
}

string[] translateEnum(in from!"clang".Cursor cursor,
                       ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.typecons: nullable;

    assert(cursor.kind == Cursor.Kind.EnumDecl);

    // Translate it twice so that C semantics are the same (global names)
    // but also have a named version for optional type correctness and
    // reflection capabilities.
    // This means that `enum Foo { foo, bar }` in C will become:
    // `enum Foo { foo, bar }` _and_
    // `enum foo = Foo.foo; enum bar = Foo.bar;` in D.

    auto enumName = context.spellingOrNickname(cursor);

    string[] lines;
    foreach(member; cursor) {
        if(!member.isDefinition) continue;
        auto memName = member.spelling;
        lines ~= `enum ` ~ memName ~ ` = ` ~ enumName ~ `.` ~ memName ~ `;`;
    }

    return
        translateAggregate(context, cursor, "enum", nullable(enumName)) ~
        lines;
}

// not pure due to Cursor.opApply not being pure
string[] translateAggregate(
    ref from!"dpp.runtime.context".Context context,
    in from!"clang".Cursor cursor,
    in string keyword,
    in from!"std.typecons".Nullable!string spelling = from!"std.typecons".Nullable!string()
)
    @safe
{
    return translateAggregate(context, cursor, keyword, keyword, spelling);
}

// not pure due to Cursor.opApply not being pure
string[] translateAggregate(
    ref from!"dpp.runtime.context".Context context,
    in from!"clang".Cursor cursor,
    in string cKeyword,
    in string dKeyword,
    in from!"std.typecons".Nullable!string spelling = from!"std.typecons".Nullable!string()
)
    @safe
{
    import dpp.cursor.translation: translate;
    import clang: Cursor, Type;
    import std.algorithm: map;
    import std.array: array;
    import std.conv: text;

    // remember all aggregate declarations
    context.rememberAggregate(cursor);

    const name = spelling.isNull ? context.spellingOrNickname(cursor) : spelling.get;
    const realDlangKeyword = cursor.semanticParent.type.canonical.kind == Type.Kind.Record
        ? "static " ~ dKeyword
        : dKeyword;
    const firstLine = realDlangKeyword ~ ` ` ~ name;

    if(!cursor.isDefinition) return [firstLine ~ `;`];

    string[] lines;
    lines ~= firstLine;
    lines ~= `{`;

    if(cKeyword == "class") lines ~= "private:";

    lines ~= maybeBitFieldHeader(cursor);

    // if the last seen member was a bitfield
    bool lastMemberWasBitField = false;
    // the combined (summed) bitwidths of the bitfields members seen so far
    int totalBitWidth = 0;

    context.log("Children: ", cursor.children);

    foreach(member; cursor.children) {

        if(member.kind == Cursor.Kind.PackedAttr) {
            lines ~= "align(1):";
            continue;
        }

        if(member.isBitField && !lastMemberWasBitField)
            lines ~= `    mixin(bitfields!(`;

        if(!member.isBitField && lastMemberWasBitField) lines ~= finishBitFields(totalBitWidth);

        if(skipMember(member)) continue;

        lines ~= translate(member, context).map!(a => "    " ~ a).array;
        // Deal with C11 anonymous structs/unions. See issue #29.
        lines ~= handleC11AnonymousRecords(cursor, member, context);

        lastMemberWasBitField = member.isBitField;
        if(member.isBitField) totalBitWidth += member.bitWidth;
    }

    if(lastMemberWasBitField) lines ~= finishBitFields(totalBitWidth);

    lines ~= `}`;

    return lines;
}

private string[] maybeBitFieldHeader(in from!"clang".Cursor cursor) @safe nothrow {
    import std.algorithm: any;

    if(cursor.children.any!(a => a.isBitField)) {
        // The align(4) is to mimic C. There, `struct Foo { int f1: 2; int f2: 3}`
        // would have sizeof 4, where as the corresponding bit fields in D would have
        // size 1. So we correct here. See issue #7.
        return [`    import std.bitmanip: bitfields;`, ``, `    align(4):`];
    } else
        return [];
}

private bool skipMember(in from!"clang".Cursor member) @safe @nogc pure nothrow {
    import clang: Cursor;
    return
        !member.isDefinition &&
        member.kind != Cursor.Kind.CXXMethod &&
        member.kind != Cursor.Kind.Constructor &&
        member.kind != Cursor.Kind.Destructor &&
        member.kind != Cursor.Kind.VarDecl &&
        member.kind != Cursor.Kind.CXXBaseSpecifier;
}

private string[] finishBitFields(scope ref int totalBitWidth) @safe pure nothrow {
    import std.conv: text;
    string[] lines;
    lines ~= text(`        uint, "", `, padding(totalBitWidth));
    lines ~= `    ));`;
    totalBitWidth = 0;
    return lines;
}


private int padding(in int totalBitWidth) @safe @nogc pure nothrow {
    for(int powerOfTwo = 8; powerOfTwo < 64; powerOfTwo *= 2) {
        if(powerOfTwo > totalBitWidth) return powerOfTwo - totalBitWidth;
    }

    assert(0);
}


string[] translateField(in from!"clang".Cursor field,
                        ref from!"dpp.runtime.context".Context context)
    @safe
{

    import dpp.cursor.dlang: maybeRename;
    import dpp.type: translate;
    import clang: Cursor, Type;
    import std.conv: text;
    import std.typecons: No;
    import std.array: replace;

    assert(field.kind == Cursor.Kind.FieldDecl, text("Field of wrong kind: ", field));

    // The field could be a pointer to an undeclared struct or a function pointer with parameter
    // or return types that are a pointer to an undeclared struct. We have to remember these
    // so as to be able to declare the structs for D consumption after the fact.
    if(field.type.kind == Type.Kind.Pointer) maybeRememberStructsFromType(field.type, context);

    // Remember the field name in case it ends up clashing with a type.
    context.rememberField(field.spelling);

    const type = translate(field.type, context, No.translatingFunction);

    return field.isBitField
        ? [text("    ", type, `, "`, maybeRename(field, context), `", `, field.bitWidth, `,`)]
        : [text(type, " ", maybeRename(field, context), ";")];
}


private void maybeRememberStructsFromType(in from!"clang".Type type,
                                          ref from!"dpp.runtime.context".Context context)
    @safe pure
{
    import clang: Type;
    import std.range: only, chain;

    const pointeeType = type.pointee.canonical;
    const isFunction =
        pointeeType.kind == Type.Kind.FunctionProto ||
        pointeeType.kind == Type.Kind.FunctionNoProto;

    if(pointeeType.kind == Type.Kind.Record)
        maybeRememberStructs([type], context);
    else if(isFunction)
        maybeRememberStructs(chain(only(pointeeType.returnType), pointeeType.paramTypes),
                             context);
}

void maybeRememberStructs(R)(R types, ref from!"dpp.runtime.context".Context context)
    @safe pure if(isInputRange!R)
{
    import dpp.type: translate;
    import clang: Type;
    import std.algorithm: map, filter;

    auto structTypes = types
        .filter!(a => a.kind == Type.Kind.Pointer && a.pointee.canonical.kind == Type.Kind.Record)
        .map!(a => a.pointee.canonical);

    void rememberStruct(in Type pointeeCanonicalType) {
        const translatedType = translate(pointeeCanonicalType, context);
        // const becomes a problem if we have to define a struct at the end of all translations.
        // See it.compile.projects.nv_alloc_ops
        enum constPrefix = "const(";
        const cleanedType = pointeeCanonicalType.isConstQualified
            ? translatedType[constPrefix.length .. $-1] // unpack from const(T)
            : translatedType;

        if(cleanedType != "va_list")
            context.rememberFieldStruct(cleanedType);
    }

    foreach(structType; structTypes)
        rememberStruct(structType);
}

// if the cursor is an aggregate in C, i.e. struct, union or enum
package bool isAggregateC(in from!"clang".Cursor cursor) @safe @nogc pure nothrow {
    import clang: Cursor;
    return
        cursor.kind == Cursor.Kind.StructDecl ||
        cursor.kind == Cursor.Kind.UnionDecl ||
        cursor.kind == Cursor.Kind.EnumDecl;
}


private string[] handleC11AnonymousRecords(in from!"clang".Cursor cursor,
                                           in from!"clang".Cursor member,
                                           ref from!"dpp.runtime.context".Context context)
    @safe

{
    import dpp.type: translate, hasAnonymousSpelling;
    import clang: Cursor, Type;
    import std.algorithm: any, filter;

    if(member.type.kind != Type.Kind.Record || member.spelling != "") return [];

    // Either a field or an array of the type we expect
    bool isFieldOfRightType(in Cursor member, in Cursor child) {
        const isField =
            child.kind == Cursor.Kind.FieldDecl &&
            child.type.canonical == member.type.canonical;

        const isArrayOf = child.type.elementType.canonical == member.type.canonical;
        return isField || isArrayOf;
    }

    // Check if the parent cursor has any fields have this type.
    // If so, we don't need to declare a dummy variable.
    const anyFields = cursor.children.any!(a => isFieldOfRightType(member, a));
    if(anyFields) return [];

    string[] lines;
    const varName = context.newAnonymousMemberName;

    //lines ~= "    " ~ translate(member.type, context) ~ " " ~  varName ~ ";";
    const dtype = translate(member.type, context);
    lines ~= "    " ~ dtype ~ " " ~  varName ~ ";";

    foreach(subMember; member.children) {
        if(subMember.kind == Cursor.Kind.FieldDecl)
            lines ~= innerFieldAccessors(varName, subMember);
        else if(subMember.type.canonical.kind == Type.Kind.Record &&
                hasAnonymousSpelling(subMember.type.canonical) &&
                !member.children.any!(a => isFieldOfRightType(subMember, a))) {
            foreach(subSubMember; subMember) {
                lines ~= "        " ~ innerFieldAccessors(varName, subSubMember);
            }
        }
    }

    return lines;
}


// functions to emulate C11 anonymous structs/unions
private string[] innerFieldAccessors(in string varName, in from !"clang".Cursor subMember) @safe {
    import std.format: format;
    import std.algorithm: map;
    import std.array: array;

    string[] lines;

    const fieldAccess = varName ~ "." ~ subMember.spelling;
    const funcName = subMember.spelling;

    lines ~= q{auto %s() @property @nogc pure nothrow { return %s; }}
        .format(funcName, fieldAccess);

    lines ~= q{void %s(_T_)(auto ref _T_ val) @property @nogc pure nothrow { %s = val; }}
        .format(funcName, fieldAccess);

    return lines.map!(a => "    " ~ a).array;
}
