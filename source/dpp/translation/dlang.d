/**
   Deals with D-specific translation, such as avoiding keywords
 */
module dpp.translation.dlang;

import dpp.from;


string maybeRename(in from!"clang".Cursor cursor,
                   in from!"dpp.runtime.context".Context context)
    @safe pure nothrow
{
    return nameClashes(cursor, context)
        ? rename(cursor.spelling, context)
        : cursor.spelling.idup;
}

string maybePragma(in from!"clang".Cursor cursor,
                   in from!"dpp.runtime.context".Context context)
    @safe pure nothrow
{
    import dpp.runtime.context: Language;
    import std.algorithm: startsWith;
    const isCpp = context.language == Language.Cpp;
    if(isCpp) return pragmaMangle(cursor.mangling);
    return nameClashes(cursor, context) ? pragmaMangle(cursor.mangling) : "";
}

string rename(string spelling,
              in from!"dpp.runtime.context".Context context)
    @safe pure nothrow
{
    do
        spelling ~= "_";
    while(spelling in context.aggregateDeclarations || isKeyword(spelling));

    return spelling;
}

string pragmaMangle(in string mangling) @safe pure nothrow {
    return mangling == "" ? "" : `pragma(mangle, "` ~ mangling ~ `") `;
}

private bool nameClashes(in from!"clang".Cursor cursor,
                         in from!"dpp.runtime.context".Context context)
    @safe pure nothrow
{
    return
        cursor.spelling.isKeyword ||
        cursor.spelling in context.aggregateDeclarations;
}

bool isKeyword(string str) @safe @nogc pure nothrow {
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
