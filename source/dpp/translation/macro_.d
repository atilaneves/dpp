module dpp.translation.macro_;

import dpp.from;

string[] translateMacro(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.dlang: maybeRename;
    import clang: Cursor;
    import std.file: exists;
    import std.algorithm: startsWith;
    import std.conv: text;

    assert(cursor.kind == Cursor.Kind.MacroDefinition);

    // we want non-built-in macro definitions to be defined and then preprocessed
    // again

    auto range = cursor.sourceRange;

    if(range.path == "" || !range.path.exists ||
       cursor.isPredefined || cursor.spelling.startsWith("__STDC_")) { //built-in macro
        return [];
    }

    // the only sane way for us to be able to see a macro definition
    // for a macro that has already been defined is if an #undef happened
    // in the meanwhile. Unfortunately, libclang has no way of passing
    // that information to us
    string maybeUndef;
    if(context.macroAlreadyDefined(cursor))
        maybeUndef = "#undef " ~ cursor.spelling ~ "\n";

    context.rememberMacro(cursor);
    const spelling = maybeRename(cursor, context);
    const body_ = range.chars.text[cursor.spelling.length .. $];
    const dbody = translateToD(body_, context);

    auto redefinition = [maybeUndef ~ "#define " ~ spelling ~ dbody ~ "\n"];

    // Always redefine the macro, but sometimes also add a D enum
    // See #103 for why.
    return onlyRedefine(cursor, dbody)
        ? redefinition
        : redefinition ~ [`enum DPP_ENUM_` ~ spelling ~ ` = ` ~ dbody ~ `;`];
}


private auto chars(in from!"clang".SourceRange range) @safe {
    import std.stdio: File;

    const startPos = range.start.offset;
    const endPos   = range.end.offset;

    auto file = File(range.path);
    file.seek(startPos);
    return () @trusted { return file.rawRead(new char[endPos - startPos]); }();
}


// whether the macro should only be re-#defined
private bool onlyRedefine(in from!"clang".Cursor cursor, in string dbody) @safe pure {
    import std.string: strip;
    import std.conv: to;
    import std.exception: collectException;

    const isBodyString = dbody.strip.length >=2 && dbody[0] == '"' && dbody.strip[$-1] == '"';
    long dummyLong;
    const isBodyInteger = dbody.strip.to!long.collectException(dummyLong) is null;
    double dummyDouble;
    const isBodyFloating = dbody.strip.to!double.collectException(dummyDouble) is null;

    // See #103 for check to where it's a macro function or not
    return
        cursor.isMacroFunction || (!isBodyString && !isBodyInteger && !isBodyFloating);

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
