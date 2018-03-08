/**
   Deals with expanding 3include directives inline.
 */
module expansion;

version(unittest) {
    import unit_threaded;
    import include.test_util;
}


/**
   If an #include directive, expand in place,
   otherwise do nothing (i.e. return the same line)
 */
string maybeExpand(string line) @safe {

    const headerName = getHeaderName(line);

    return headerName == ""
        ? line
        : expand(headerName.toFileName);
}


@("translate no include")
@safe unittest {
    "foo".maybeExpand.shouldEqual("foo");
    "bar".maybeExpand.shouldEqual("bar");
}

private string getHeaderName(string line) @safe pure {
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
    getHeaderName(`#include "foo.h"`).shouldEqual(`foo.h`);
    getHeaderName(`#include "bar.h"`).shouldEqual(`bar.h`);
    getHeaderName(`#include "foo.h" // comment`).shouldEqual(`foo.h`);
    getHeaderName(`#include <foo.h>`).shouldEqual(`foo.h`);
    getHeaderName(`    #include "foo.h"`).shouldEqual(`foo.h`);
}

// transforms a header name, e.g. stdio.h
// into a full file path, e.g. /usr/include/stdio.h
private string toFileName(in string headerName) @safe {

    import std.algorithm: map, filter;
    import std.path: buildPath, absolutePath;
    import std.file: exists;
    import std.conv: text;
    import std.exception: enforce;

    if(headerName.exists) return headerName;

    const dirs = ["/usr/include"];
    auto filePaths = dirs.map!(a => buildPath(a, headerName).absolutePath).filter!exists;
    enforce(!filePaths.empty, text("Cannot find file path for header '", headerName, "'"));
    return filePaths.front;
}


string expand(in string headerFileName, in string file = __FILE__, in size_t line = __LINE__)
    @safe
{
    import include.translation: translate;
    import clang: parse, TranslationUnitFlags;
    import std.array: join;

    string[] ret;

    ret ~= "extern(C) {";

    auto translationUnit = parse(headerFileName,
                                 TranslationUnitFlags.DetailedPreprocessingRecord);

    foreach(cursor, parent; translationUnit) {
        ret ~= translate(translationUnit, cursor, parent, file, line);
    }

    ret ~= "}";
    ret ~= "";

    return ret.join("\n");
}
