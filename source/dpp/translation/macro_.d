module dpp.translation.macro_;

import dpp.from;

string[] translateMacro(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.dlang: maybeRename;
    import clang: Cursor;
    import std.algorithm: map;
    import std.string: join;
    import std.file: exists;
    import std.stdio: File;
    import std.algorithm: startsWith;
    import std.conv: text, to;
    import std.exception: collectException;
    import std.string: strip;

    assert(cursor.kind == Cursor.Kind.MacroDefinition);

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
    if(context.macroAlreadyDefined(cursor))
        maybeUndef = "#undef " ~ cursor.spelling ~ "\n";

    context.rememberMacro(cursor);
    const spelling = maybeRename(cursor, context);
    const body_ = chars.text[cursor.spelling.length .. $];
    const dbody = translateToD(body_, context);

    const isBodyString = dbody.strip.length >=2 && dbody[0] == '"' && dbody.strip[$-1] == '"';
    long dummyLong;
    const isBodyInteger = dbody.strip.to!long.collectException(dummyLong) is null;
    double dummyDouble;
    const isBodyFloating = dbody.strip.to!double.collectException(dummyDouble) is null;

    // See #103 for check to where it's a macro function or not
    const redefineOnly =
        cursor.isMacroFunction || (!isBodyString && !isBodyInteger && !isBodyFloating);

    auto redefinition = [maybeUndef ~ "#define " ~ spelling ~ dbody ~ "\n"];

    // Always redefine the macro, but sometimes also add a D enum
    return redefineOnly
        ? redefinition
        : redefinition ~ [`enum DPP_ENUM_` ~ spelling ~ ` = ` ~ dbody ~ `;`];
}


// Some macros define snippets of C code that aren't valid D
private string translateToD(in string line, in from!"dpp.runtime.context".Context context) @safe {
    import std.array: replace;
    import std.regex: regex, replaceAll;

    auto sizeofRegex = regex(`sizeof *?\(([^)]+)\)`);

    return line
        .replace("->", ".")
        .replaceNull
        .replaceAll(sizeofRegex, "($1).sizeof")
        .replaceAll(context.castRegex, "cast($1)")
        ;
}

private string replaceNull(in string str) @safe pure nothrow {
    import std.array: replace;
    import std.algorithm: startsWith;
    // we don't want to translate the definition of NULL itself
    return str.startsWith("NULL") ? str : str.replace("NULL", "null");
}
