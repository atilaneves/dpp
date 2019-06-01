module dpp.translation.macro_;

import dpp.from;

string[] translateMacro(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.MacroDefinition)
{
    import dpp.translation.dlang: maybeRename;
    import clang: Cursor;
    import std.file: exists;
    import std.algorithm: startsWith, canFind;
    import std.conv: text;

    // we want non-built-in macro definitions to be defined and then preprocessed
    // again

    const tokens = cursor.tokens;
    if(isBuiltinMacro(cursor)) return [];

    // the only sane way for us to be able to see a macro definition
    // for a macro that has already been defined is if an #undef happened
    // in the meanwhile. Unfortunately, libclang has no way of passing
    // that information to us
    string maybeUndef;
    if(context.macroAlreadyDefined(cursor))
        maybeUndef = "#undef " ~ cursor.spelling ~ "\n";

    context.rememberMacro(cursor);
    const spelling = maybeRename(cursor, context);
    const body_ = cursor.sourceRange.chars.text[cursor.spelling.length .. $];
    const dbody = translateToD(body_, context);

    auto redefinition = [maybeUndef ~ "#define " ~ spelling ~ dbody ~ "\n"];

    // Always redefine the macro, but sometimes also add a D enum
    // See #103 for why.
    return onlyRedefine(cursor, tokens)
        ? redefinition
        : redefinition ~ [`enum DPP_ENUM_` ~ spelling ~ ` = ` ~ dbody ~ `;`];
}


bool isBuiltinMacro(in from!"clang".Cursor cursor)
    @safe @nogc
{
    import clang: Cursor;
    import std.file: exists;
    import std.algorithm: startsWith;

    if(cursor.kind != Cursor.Kind.MacroDefinition) return false;

    return
        cursor.sourceRange.path == ""
        || !cursor.sourceRange.path.exists
        || cursor.isPredefined
        || cursor.spelling.startsWith("__STDC_")
        ;
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
private bool onlyRedefine(in from!"clang".Cursor cursor, in from!"clang".Token[] tokens) @safe {
    import clang: Token;

    // always redefine function-like macros
    if(cursor.isMacroFunction) return true;

    // otherwise, might be able to use literal macros as-is
    const isLiteralMacro =
        tokens.length == 2
        && tokens[0].kind == Token.Kind.Identifier
        && tokens[1].kind == Token.Kind.Literal
        ;

    return !isLiteralMacro;
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
        .fixLongLong
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


private string fixLongLong(in string str) @safe pure nothrow {
    import std.algorithm: endsWith;

    return str.endsWith("LL")
        ? str[0 .. $-1]
        : str;
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
