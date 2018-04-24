module dpp.cursor.macro_;

import dpp.from;

string[] translateMacro(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.algorithm: map;
    import std.string: join;
    import std.file: exists;
    import std.stdio: File;
    import std.algorithm: startsWith;
    import std.conv: text;

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
    const chars = () @trusted { return file.rawRead(new char[endPos - startPos]); }();

    // the only sane way for us to be able to see a macro definition
    // for a macro that has already been defined is if an #undef happened
    // in the meanwhile. Unfortunately, libclang has no way of passing
    // that information to us
    string maybeUndef;
    if(cursor.spelling in alreadyDefined)
        maybeUndef = "#undef " ~ cursor.spelling ~ "\n";

    alreadyDefined[cursor.spelling] = true;

    return [maybeUndef ~ "#define " ~ translateToD(chars.text, context) ~ "\n"];
}


// Some macros define snippets of C code that aren't valid D
private string translateToD(in string line, in from!"dpp.runtime.context".Context context) @safe {
    import std.array: replace;
    import std.regex: regex, replaceAll;

    auto sizeofRegex = regex(`sizeof *?\(([^)]+)\)`);

    return line
        .replace("->", ".")
        .replaceNull
        .replaceAll(sizeofRegex, "$1.sizeof")
        .replaceAll(context.castRegex, "cast($1)")
        ;
}

private string replaceNull(in string str) @safe pure nothrow {
    import std.array: replace;
    import std.algorithm: startsWith;
    // we don't want to translate the definition of NULL itself
    return str.startsWith("NULL") ? str : str.replace("NULL", "null");
}
