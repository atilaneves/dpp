module include.runtime;

version(unittest) {
    import unit_threaded;
    import include.test_util;
}

void run(string[] args) {

}

void preprocess(File)(in string inputFileName, in string outputFileName) {

    import include.translation: translate;
    import std.algorithm: map;
    import std.string: join;

    auto outputFile = File(outputFileName, "w");

    foreach(line; File(inputFileName).byLine.map!(a => cast(string)a)) {
        outputFile.writeln(line.translate.join("\n"));
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
