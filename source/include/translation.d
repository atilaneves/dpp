module include.translation;


version(unittest) {
    import unit_threaded;
    import include.test_util;
}



string[] translate(in string line) @safe {

    import std.exception: enforce;

    const headerFileName = getHeaderFileName(line);

    if(headerFileName == "") {
        return [line];
    }

    enforce(headerFileName.exists,
            "Cannot open " ~ headerFileName);

    return expand(headerFileName);
}


@("translate no include")
@safe unittest {
    "foo".translate.shouldEqual(["foo"]);
    "bar".translate.shouldEqual(["bar"]);
}


private string[] expand(in string headerFileName) @safe pure nothrow {
    return [""];
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

private bool exists(in string fileName) @safe {
    version(unittest) {
        return TestFile.exists(fileName);
    } else {
        import std.file: _exists = exists;
        return fileName._exists;
    }
}
