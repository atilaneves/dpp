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


string[] translate(from!"clang".Cursor cursor, in string file = __FILE__, in size_t line = __LINE__) @safe {

    import std.conv: text;
    import std.exception: enforce;
    version(unittest) import unit_threaded.io: writelnUt;

    version(unittest) {
        import clang: Cursor;
        import std.algorithm: startsWith;

        if(cursor.kind != Cursor.Kind.MacroDefinition || !cursor.spelling.startsWith("__"))
            debug writelnUt("Cursor: ", cursor);
    }

    if(cursor.kind !in translations)
        throw new Exception(text("Cannot translate unknown cursor kind ", cursor.kind), file, line);

    return translations[cursor.kind](cursor);
}

Translation[from!"clang".Cursor.Kind] translations() @safe pure {
    import include.translation;
    import clang: Cursor;

    with(Cursor.Kind) {
        return [
            StructDecl:      &translateStruct,
            UnionDecl:       &translateUnion,
            FunctionDecl:    &translateFunction,
            FieldDecl:       &translateField,
            TypedefDecl:     &translateTypedef,
            MacroDefinition: &translateMacro,
        ];
    }
}

string[] translateMacro(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor;
    import std.format: format;
    import std.algorithm: map;
    import std.string: join;
    import std.file: exists;
    import std.stdio: File;
    import std.algorithm: startsWith;

    assert(cursor.kind == Cursor.Kind.MacroDefinition);

    static bool[string] alreadyDefined;

    // we want non-built-in macro definitions to be defined and then preprocessed
    // again

    auto range = cursor.sourceRange;

    if(range.path == "" || !range.path.exists ||
       cursor.isPredefined || cursor.spelling.startsWith("__STDC_")) { //built-in macro
        return [];
    }

    // now we read the header where the macro comes from and copy the text inline

    const startPos = range.start.offset;
    const endPos   = range.end.offset;

    auto file = File(range.path);
    file.seek(startPos);
    const chars = file.rawRead(new char[endPos - startPos]);

    // the only sane way for us to be able to see a macro definition
    // for a macro that has already been defined is if an #undef happened
    // in the meanwhile. Unfortunately, libclang has no way of passing
    // that information to us
    string maybeUndef;
    if(cursor.spelling in alreadyDefined)
        maybeUndef = "#undef " ~ cursor.spelling ~ "\n";

    alreadyDefined[cursor.spelling] = true;

    return [maybeUndef ~ "#define %s\n".format(chars)];
}
