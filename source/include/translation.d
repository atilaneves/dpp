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

    string ret = "extern(C) {\n";
    auto translationUnit = parse(headerFileName);

    foreach(cursor, parent; translationUnit) {
        ret ~= translate(translationUnit, cursor, parent);
    }

    ret ~= "}\n";

    return ret;
}

private string translate(ref TranslationUnit translationUnit, ref Cursor cursor, ref Cursor parent) @trusted {

    import dstep.translator.Output: Output;
    import dstep.translator.Translator: Translator;
    import std.string: replace;

    if(skipCursor(cursor)) return "";

    auto translator = new Translator(translationUnit._impl);
    Output output = new Output(translator.context.commentIndex);

    translator.translateInGlobalScope(output, cursor._impl, parent._impl);
    if (translator.context.commentIndex)
        output.flushLocation(translator.context.commentIndex.queryLastLocation());

    // foreach (value; translator.deferredDeclarations.values)
    //     output.singleLine(value);

    output.finalize();


    return output.content.replace("9223372036854775807LL", "9223372036854775807L");
}

private bool skipCursor(ref Cursor cursor) {
    import std.algorithm: endsWith;
    if(cursor.spelling == "__VERSION__") return true;
    if(cursor.spelling == "__FLT_DENORM_MIN__") return true;
    if(cursor.spelling == "__DBL_DENORM_MIN__") return true;
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
