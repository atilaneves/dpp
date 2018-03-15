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
    import std.algorithm: map;

    return cursor.skip
        ? ""
        : translate(cursor, file, line).map!(a => "    " ~ a).join("\n");
}

private bool skip(in from!"clang".Cursor cursor) @safe pure {
    import clang: Cursor;
    import std.algorithm: startsWith, canFind;

    static immutable forbiddenSpellings =
        [
            "ulong", "ushort", "uint",
            "va_list", "__gnuc_va_list",
            "_IO_2_1_stdin_", "_IO_2_1_stdout_", "_IO_2_1_stderr_",
        ];

    return forbiddenSpellings.canFind(cursor.spelling) ||
        cursor.isPredefined ||
        cursor.kind == Cursor.Kind.MacroExpansion
        ;
}


string[] translate(from!"clang".Cursor cursor, in string file = __FILE__, in size_t line = __LINE__)
    @safe
{
    import std.conv: text;

    debugCursor(cursor);

    if(cursor.kind !in translations)
        throw new Exception(text("Cannot translate unknown cursor kind ", cursor.kind), file, line);

    return translations[cursor.kind](cursor);
}

private void debugCursor(in from!"clang".Cursor cursor) @safe {
    version(unittest) {
        import clang: Cursor;
        import unit_threaded.io: writelnUt;
        import std.algorithm: startsWith;

        if(cursor.kind != Cursor.Kind.MacroDefinition || !cursor.spelling.startsWith("__"))
            debug writelnUt("Cursor: ", cursor);
    }
}

Translation[from!"clang".Cursor.Kind] translations() @safe {
    import include.translation;
    import clang: Cursor;
    import include.expansion: expand;

    static string[] ignore(in Cursor cursor) { return []; }

    with(Cursor.Kind) {
        return [
            StructDecl:         &translateStruct,
            UnionDecl:          &translateUnion,
            EnumDecl:           &translateEnum,
            FunctionDecl:       &translateFunction,
            FieldDecl:          &translateField,
            TypedefDecl:        &translateTypedef,
            MacroDefinition:    &translateMacro,
            InclusionDirective: &ignore,
            EnumConstantDecl:   &translateEnumConstant,
        ];
    }
}
