module dpp.translation.macro_;

import dpp.from;

string[] translateMacro(in from!"dpp.ast.node".Node node,
                        ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.dlang: maybeRename;
    import clang: Cursor;
    import std.file: exists;
    import std.algorithm: startsWith, canFind;
    import std.conv: text;

    assert(node.kind == Cursor.Kind.MacroDefinition);

    // we want non-built-in macro definitions to be defined and then preprocessed
    // again

    auto range = node.sourceRange;

    if(range.path == "" || !range.path.exists ||
       node.isPredefined || node.spelling.startsWith("__STDC_")) { //built-in macro
        return [];
    }

    // the only sane way for us to be able to see a macro definition
    // for a macro that has already been defined is if an #undef happened
    // in the meanwhile. Unfortunately, libclang has no way of passing
    // that information to us
    string maybeUndef;
    if(context.macroAlreadyDefined(node))
        maybeUndef = "#undef " ~ node.spelling ~ "\n";

    context.rememberMacro(node);
    const spelling = maybeRename(node, context);
    const body_ = range.chars.text[node.spelling.length .. $];
    const dbody = translateToD(body_, context);

    auto redefinition = [maybeUndef ~ "#define " ~ spelling ~ dbody ~ "\n"];

    // Always redefine the macro, but sometimes also add a D enum
    // See #103 for why.
    return onlyRedefine(node, dbody)
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
    import std.algorithm: canFind;

    const isBodyString = dbody.strip.length >=2 && dbody[0] == '"' && dbody.strip[$-1] == '"';
    const isBodyInteger = dbody.isStringRepr!long;
    const isBodyFloating = dbody.isStringRepr!double;
    const isOctal = dbody.strip.canFind("octal!");

    // See #103 for check to where it's a macro function or not
    return
        cursor.isMacroFunction ||
        (!isBodyString && !isBodyInteger && !isBodyFloating && !isOctal);
}

private bool isStringRepr(T)(in string str) @safe pure {
    import std.conv: to;
    import std.exception: collectException;
    import std.string: strip;

    T dummy;
    return str.strip.to!T.collectException(dummy) is null;
}


// Some macros define snippets of C code that aren't valid D
// We attempt to translate them here.
private string translateToD(in string line, in from!"dpp.runtime.context".Context context) @trusted {
    import dpp.translation.type: translateElaborated;
    import dpp.translation.exception: UntranslatableException;
    import std.array: replace;
    import std.regex: regex, replaceAll;

    static typeof(regex(``)) sizeofRegex = void;
    static bool init;

    if(!init) {
        init = true;
        sizeofRegex = regex(`sizeof *?\(([^)]+)\)`);
    }

    auto replacements = line
        .replace("->", ".")
        .replaceNull
        ;

    string regexReps;

    try {
        regexReps = replacements
            .replaceAll(sizeofRegex, "($1).sizeof")
            .replaceAll(context.castRegex, "cast($1)")
            ;
    } catch(Exception ex)
        throw new UntranslatableException("Regex substitution failed: " ~ ex.msg);

    return regexReps
        .fixOctal
        .translateElaborated
        ;
}


private string replaceNull(in string str) @safe pure nothrow {
    import std.array: replace;
    import std.algorithm: startsWith;
    // we don't want to translate the definition of NULL itself
    return str.startsWith("NULL") ? str : str.replace("NULL", "null");
}

private string fixOctal(in string str) @safe pure {
    import std.string: strip;
    import std.algorithm: countUntil, all;
    import std.exception: enforce;
    import std.uni: isWhite;

    const stripped = str.strip;
    const isOctal =
        stripped.length > 1 &&
        stripped[0] == '0' &&
        stripped.isStringRepr!long;

    if(!isOctal) return str;

    const firstNonZero = stripped.countUntil!(a => a != '0');

    if(firstNonZero == -1) {
        enforce(str.all!(a => a == '0' || a.isWhite), "Cannot fix octal '" ~ str ~ "'");
        return "0";
    }

    return ` std.conv.octal!` ~ stripped[firstNonZero .. $];
}
