/**
   Translation unit translations.
 */
module include.translation.unit;

import include.from;


string translate(ref from!"clang".TranslationUnit translationUnit,
                 ref from!"clang".Cursor cursor,
                 ref from!"clang".Cursor parent)
    @safe
{
    import std.array: join;

    if(skipCursor(cursor)) return "";

    return translate(cursor).join("\n");
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


string[] translate(from!"clang".Cursor cursor) @safe {

    import include.translation.struct_: translateStruct;
    import include.translation.function_: translateFunction;
    import clang: Cursor;
    import std.conv: text;
    import std.array: join;

    switch(cursor.kind) with(Cursor.Kind) {
        default:
            return [];

        case StructDecl:
            return translateStruct(cursor);

        case FunctionDecl:
            return translateFunction(cursor);
    }
}
