/**
   Translation unit translations.
 */
module include.translation.unit;

import include.from;

alias Translation = string[] function(in from!"clang".Cursor cursor) @safe;

string translate(ref from!"clang".TranslationUnit translationUnit,
                 ref from!"clang".Cursor cursor,
                 ref from!"clang".Cursor parent,
                 in string file = __FILE__,
                 in size_t line = __LINE__)
    @safe
{
    import std.array: join;

    if(skipCursor(cursor)) return "";

    return translate(cursor, file, line).join("\n");
}

private bool skipCursor(ref from!"clang".Cursor cursor) @safe pure {
    import std.algorithm: startsWith, canFind;

    static immutable forbiddenSpellings =
        [
            "ulong", "ushort", "uint",
            "va_list", "__gnuc_va_list",
            "_IO_2_1_stdin_", "_IO_2_1_stdout_", "_IO_2_1_stderr_",
        ];

    return forbiddenSpellings.canFind(cursor.spelling) || cursor.isPredefined;
}


string[] translate(from!"clang".Cursor cursor, in string file = __FILE__, in size_t line = __LINE__) @safe {

    import std.conv: text;
    import std.exception: enforce;
    version(unittest) import unit_threaded.io: writelnUt;

    version(unittest) writelnUt("Cursor: ", cursor);

    if(cursor.kind !in translations)
        throw new Exception(text("Unknown cursor kind ", cursor.kind), file, line);

    return translations[cursor.kind](cursor);
}

Translation[from!"clang".Cursor.Kind] translations() @safe pure {
    import include.translation;
    import clang: Cursor;

    with(Cursor.Kind) {
        return [
            StructDecl: &translateStruct,
            FunctionDecl: &translateFunction,
        ];
    }
}
