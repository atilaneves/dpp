module include.runtime;

version(unittest) import unit_threaded;

void run(string[] args) {

}

void preprocess(File)(in string inputFileName, in string outputFileName) {
    import std.algorithm: startsWith, map, find;
    import std.range: dropBack;
    import std.array: empty, popFront;
    import std.exception: enforce;

    // line -> replacement
    string[string] replacements;

    auto outputFile = File(outputFileName, "w");

    foreach(line; File(inputFileName).byLine.map!(a => cast(string)a)) {

        const headerFileName = getHeaderFileName(line);

        if(headerFileName == "") {
            outputFile.writeln(line);
            continue;
        }

        enforce(headerFileName.exists,
                "Cannot open " ~ headerFileName);

        outputFile.write(expand(headerFileName));
    }
}

@("preprocess no includes")
@safe unittest {

    const inputFileName = "no_include.d_";
    TestFile.writeFile(inputFileName,
                       [`void main() {}`]);

    const outputFileName = "no_include.d";
    preprocess!TestFile(inputFileName, outputFileName);

    TestFile.output(outputFileName).shouldEqual([`void main() {}`]);
}

@("preprocess simple include")
@safe unittest {

    TestFile.writeFile(`foo.h`, [`int add(int i, int j);`]);

    const inputFileName = "simple_include.d_";
    TestFile.writeFile(inputFileName,
                       [
                           `#include "foo.h"`,
                           `void main() {}`
                       ]);

    const outputFileName = "simple_include.d";
    preprocess!TestFile(inputFileName, outputFileName);

    TestFile.output(outputFileName).shouldEqual(
        [
            `extern(C) {`,
            `    int add(int i, int j);`,
            `}`,
            `void main() {}`,
        ]);
}


private string expand(in string headerFileName) @safe pure nothrow {
    return "";
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


version(unittest):


private struct TestFile {

    string fileName;
    string mode;
    string[] lines;
    string currentOutputLine;
    static TestFile[string] inputFiles;
    static TestFile[string] outputFiles;

    static void writeFile(in string fileName, string[] input) @safe {
        inputFiles[fileName] = TestFile();
        inputFiles[fileName].lines = input;
    }

    static string[] output(in string fileName) @safe {
        import std.exception: enforce;
        enforce(fileName in outputFiles, "No output file named " ~ fileName);
        return outputFiles[fileName].lines;
    }

    static bool exists(in string fileName) @safe @nogc nothrow {
        return fileName in inputFiles || fileName in outputFiles;
    }

    this(in string fileName, in string mode = "r") @safe {

        this.fileName = fileName;
        this.mode = mode;

        switch(mode) {
        default:
            throw new Exception("Unknown file mode: " ~ mode);
        case "r":
            lines = inputFiles[fileName].lines;
            break;
        case "w":
            outputFiles[fileName] = this;
            break;
        }
    }

    void write(T...)(auto ref T args) {
        import std.conv: text;
        import std.functional: forward;
        currentOutputLine ~= text(forward!args);
    }

    void writeln(T...)(auto ref T args) {
        write(args);
        lines ~= currentOutputLine;
        currentOutputLine = "";
        if(mode == "w") outputFiles[fileName].lines = lines;
    }

    bool exists() @safe @nogc pure nothrow const {
        return true;
    }

    inout(string)[] byLine() @safe @nogc pure nothrow inout {
        return lines;
    }
}
