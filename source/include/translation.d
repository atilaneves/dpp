module include.translation;


import include.clang: TranslationUnit, Cursor;

version(unittest) {
    import unit_threaded;
    import include.test_util;
}



string translate(string line) @safe {

    const headerFileName = getHeaderFileName(line);

    return headerFileName == ""
        ? line
        : expand(headerFileName);
}


@("translate no include")
@safe unittest {
    "foo".translate.shouldEqual("foo");
    "bar".translate.shouldEqual("bar");
}


private string expand(in string headerFileName) @safe {
    import include.clang: parse;

    string ret;

    ret ~= "extern(C) {\n";

    auto translationUnit = parse(headerFileName);

    foreach(cursor, parent; translationUnit) {
        ret ~= translate(translationUnit, cursor, parent);
    }

    ret ~= "}\n";

    return ret;
}


private string translate(ref TranslationUnit translationUnit, ref Cursor cursor, ref Cursor parent) @trusted {

    if(skipCursor(cursor)) return "";

    auto translation = translateOurselves(cursor);
    if(translation.ignore) return "";
    if(translation.value != "") return translation.value;

    return dstepTranslate(translationUnit, cursor, parent);
}

private string dstepTranslate(ref TranslationUnit translationUnit, ref Cursor cursor, ref Cursor parent) @trusted {
    import dstep.translator.Output: Output;
    import dstep.translator.Translator: Translator;
    import dstep.translator.Options: Options;
    import std.string: replace;
    import std.algorithm: canFind, startsWith;

    static bool[string] alreadyTranslated;

    Options options;
    options.enableComments = false;
    auto translator = new Translator(translationUnit._impl, options);
    Output output = new Output(translator.context.commentIndex);

    translator.translateInGlobalScope(output, cursor._impl, parent._impl);
    if (translator.context.commentIndex)
        output.flushLocation(translator.context.commentIndex.queryLastLocation());

    // foreach (value; translator.deferredDeclarations.values)
    //     output.singleLine(value);

    output.finalize();

    auto ret =  output
        .content
        .replace("9223372036854775807LL", "9223372036854775807L")
        .replace("__UINT64_C(18446744073709551615)", "__UINT64_C(18446744073709551615UL)");

    if(ret.startsWith("enum ") && ret.canFind("_TYPE = __"))
        ret = ret.replace("enum", "alias");

    if(ret in alreadyTranslated) return "";

    alreadyTranslated[ret] = true;

    return ret;
}

private struct Translation {
    string value;
    bool ignore;
}

private Translation translateOurselves(ref Cursor cursor) {
    static bool[string] alreadyTranslated;

    const translated = translateImpl(cursor);

    if(translated in alreadyTranslated) return Translation("", true);
    if(translated == "") return Translation("");

    alreadyTranslated[translated] = true;
    return Translation(translated);
}

private string translateImpl(ref Cursor cursor) {
    switch(cursor.spelling) {
    default:
        return "";
    case "UINT64_MAX":
        return "enum UINT64_MAX = ulong.max;\n";
    case "__INT64_C":
        return "private auto __INT64_C(T)(T t) { return cast(long)t; }\n";
    case "__UINT64_C":
        return "private auto __UINT64_C(T)(T t) { return cast(ulong)t; }\n";
    case "__errno_location":
        return "extern(C) int* __errno_location();\n";
    case "errno":
        return "private int erro() { return *__errno_location; }\n";
    }
}

private bool skipCursor(ref Cursor cursor) {

    import std.algorithm: endsWith, canFind;

    static immutable skippedSpellings = [
        "__VERSION__",
        "__FLT_DENORM_MIN__",
        "__DBL_DENORM_MIN__",
        "__glibc_clang_has_extension",
        "__REDIRECT_LDBL",
        "__REDIRECT_NTH_LDBL",
    ];


    if(skippedSpellings.canFind(cursor.spelling)) return true;
    if(cursor.spelling.endsWith("_C_SUFFIX__")) return true;

    return false;
}


private string getHeaderFileName(string line) @safe pure {
    import std.algorithm: startsWith, countUntil;
    import std.range: dropBack;
    import std.array: popFront;
    import std.string: stripLeft;

    line = line.stripLeft;
    if(!line.startsWith(`#include `)) return "";

    const openingQuote = line.countUntil!(a => a == '"' || a == '<');
    const closingQuote = line[openingQuote + 1 .. $].countUntil!(a => a == '"' || a == '>') + openingQuote + 1;
    return line[openingQuote + 1 .. closingQuote];
}

@("getHeaderFileName")
@safe pure unittest {
    getHeaderFileName(`#include "foo.h"`).shouldEqual(`foo.h`);
    getHeaderFileName(`#include "bar.h"`).shouldEqual(`bar.h`);
    getHeaderFileName(`#include "foo.h" // comment`).shouldEqual(`foo.h`);
    getHeaderFileName(`#include <foo.h>`).shouldEqual(`foo.h`);
    getHeaderFileName(`    #include "foo.h"`).shouldEqual(`foo.h`);
}
