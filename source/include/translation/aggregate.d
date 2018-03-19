/**
   Translate aggregates
 */
module include.translation.aggregate;

import include.from;

/**
   Structs can be anomymous in C, and it's even common
   to typedef them to a name. We come up with new names
   that we track here so as to be able to properly transate
   those typedefs.
 */
private shared string[from!"clang.c.index".CXCursor] gCursorNickNames;

/// the last nickname we coined (e.g. "_Anonymous_1")
private shared string gLastNickName;


string[] translateStruct(in from!"clang".Cursor cursor,
                         in from!"include.runtime.options".Options options =
                                from!"include.runtime.options".Options())
    @safe
{
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.StructDecl);
    return translateAggregate(options, cursor, "struct");
}

string[] translateUnion(in from!"clang".Cursor cursor,
                        in from!"include.runtime.options".Options options =
                               from!"include.runtime.options".Options())
    @safe
{
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.UnionDecl);
    return translateAggregate(options, cursor, "union");
}

string[] translateEnum(in from!"clang".Cursor cursor,
                       in from!"include.runtime.options".Options options =
                              from!"include.runtime.options".Options())
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
        translateAggregate(options, cursor, "enum") ~
        translateAggregate(options, cursor, "enum", nullable(""));
}

// not pure due to Cursor.opApply not being pure
string[] translateAggregate(
    in from!"include.runtime.options".Options options,
    in from!"clang".Cursor cursor,
    in string keyword,
    in from!"std.typecons".Nullable!string spelling = from!"std.typecons".Nullable!string()
)
    @safe
{
    import include.translation.unit: translate;
    import clang: Cursor;
    import std.algorithm: map;
    import std.array: array;

    const name = spelling.isNull ? spellingOrNickname(cursor) : spelling.get;
    if(cursor.children.length == 0) return [keyword ~ ` ` ~ name ~ `;`];

    string[] lines;
    lines ~= keyword ~ ` ` ~ name;
    lines ~= `{`;

    foreach(member; cursor) {
        lines ~= translate(member, options.indent).map!(a => "    " ~ a).array;
    }

    lines ~= `}`;

    return lines;
}


string[] translateField(in from!"clang".Cursor field,
                        in from!"include.runtime.options".Options options =
                               from!"include.runtime.options".Options()
                        )
    @safe
{

    import include.translation.type: translate;
    import clang: Cursor;
    import std.conv: text;
    import std.typecons: No;

    assert(field.kind == Cursor.Kind.FieldDecl, text("Field of wrong kind: ", field));

    return [text(translate(field.type, No.translatingFunction, options), " ", field.spelling.translateIdentifier, ";")];
}

string translateIdentifier(in string spelling) @safe pure nothrow {
    return spelling.isDKeyword ? spelling ~ "_" : spelling;
}

// return the spelling if it exists, or our made-up nickname for it
// if not
package string spellingOrNickname(in from!"clang".Cursor cursor) @safe {

    import std.conv: text;

    static int index;

    if(cursor.spelling != "") return cursor.spelling;

    if(cursor.cx !in gCursorNickNames) {
        gLastNickName = gCursorNickNames[cursor.cx] = newAnonymousName;
    }

    return gCursorNickNames[cursor.cx];
}

package string spellingOrNickname(in string typeSpelling) @safe {

    import std.algorithm: canFind;
    return typeSpelling.canFind("(anonymous") ? gLastNickName : typeSpelling;
}

private string newAnonymousName() @safe {
    import std.conv: text;
    import core.atomic: atomicOp;
    shared static int index;
    return text("_Anonymous_", index.atomicOp!"+="(1));
}

bool isDKeyword (string str) @safe @nogc pure nothrow {
    switch (str) {
        default: return false;
        case "abstract":
        case "alias":
        case "align":
        case "asm":
        case "assert":
        case "auto":

        case "body":
        case "bool":
        case "break":
        case "byte":

        case "case":
        case "cast":
        case "catch":
        case "cdouble":
        case "cent":
        case "cfloat":
        case "char":
        case "class":
        case "const":
        case "continue":
        case "creal":

        case "dchar":
        case "debug":
        case "default":
        case "delegate":
        case "delete":
        case "deprecated":
        case "do":
        case "double":

        case "else":
        case "enum":
        case "export":
        case "extern":

        case "false":
        case "final":
        case "finally":
        case "float":
        case "for":
        case "foreach":
        case "foreach_reverse":
        case "function":

        case "goto":

        case "idouble":
        case "if":
        case "ifloat":
        case "import":
        case "in":
        case "inout":
        case "int":
        case "interface":
        case "invariant":
        case "ireal":
        case "is":

        case "lazy":
        case "long":

        case "macro":
        case "mixin":
        case "module":

        case "new":
        case "nothrow":
        case "null":

        case "out":
        case "override":

        case "package":
        case "pragma":
        case "private":
        case "protected":
        case "public":
        case "pure":

        case "real":
        case "ref":
        case "return":

        case "scope":
        case "shared":
        case "short":
        case "static":
        case "struct":
        case "super":
        case "switch":
        case "synchronized":

        case "template":
        case "this":
        case "throw":
        case "true":
        case "try":
        case "typedef":
        case "typeid":
        case "typeof":

        case "ubyte":
        case "ucent":
        case "uint":
        case "ulong":
        case "union":
        case "unittest":
        case "ushort":

        case "version":
        case "void":
        case "volatile":

        case "wchar":
        case "while":
        case "with":
        case "immutable":
        case "__gshared":
        case "__thread":
        case "__traits":

        case "__EOF__":
        case "__FILE__":
        case "__LINE__":
        case "__DATE__":
        case "__TIME__":
        case "__TIMESTAMP__":
        case "__VENDOR__":
        case "__VERSION__":
            return true;
    }

    assert(0);
}
