/**
   Translation unit translations.
 */
module include.translation.unit;

import include.from;

alias Translation = string[] function(
    in from!"clang".Cursor cursor,
    in from!"include.runtime.options".Options options = from!"include.runtime.options".Options(),
    ) @safe;

string translate(in from!"include.runtime.options".Options options,
                 in from!"clang".Cursor cursor,
                 in string file = __FILE__,
                 in size_t line = __LINE__)
    @safe
{
    import std.array: join;
    import std.algorithm: map;

    return cursor.skip
        ? ""
        : translate(cursor, options, file, line).map!(a => "    " ~ a).join("\n");
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


string[] translate(in from!"clang".Cursor cursor,
                   in from!"include.runtime.options".Options options =
                          from!"include.runtime.options".Options(),
                   in string file = __FILE__,
                   in size_t line = __LINE__)
    @safe
{
    import std.conv: text;

    debugCursor(options, cursor);

    if(cursor.kind !in translations)
        throw new Exception(text("Cannot translate unknown cursor kind ", cursor.kind), file, line);

    try
        return translations[cursor.kind](cursor, options);
    catch(Exception e) {
        import std.stdio: stderr;
        debug {
            () @trusted {
                stderr.writeln("Could not translate cursor ", cursor,
                               " sourceRange: ", cursor.sourceRange,
                               " children: ", cursor.children);
            }();
        }
        throw e;
    }
}

private void debugCursor(in from!"include.runtime.options".Options options,
                         in from!"clang".Cursor cursor)
    @safe
{
    import clang: Cursor;
    import std.algorithm: startsWith, canFind;

    version(unittest) {}
    else if(!options.debugOutput) return;

    const isMacro = cursor.kind == Cursor.Kind.MacroDefinition;
    const isOkMacro =
        !cursor.spelling.startsWith("__") &&
        !["_LP64", "unix", "linux"].canFind(cursor.spelling);

    if(!isMacro || isOkMacro) {
        options.log(cursor, " @ ", cursor.sourceRange);
    }
}

Translation[from!"clang".Cursor.Kind] translations() @safe {
    import include.translation;
    import clang: Cursor;
    import include.expansion: expand;

    static string[] ignore(in Cursor cursor,
                           in from!"include.runtime.options".Options options) {
        return [];
    }

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
            VarDecl:            &translateVariable,
        ];
    }
}
