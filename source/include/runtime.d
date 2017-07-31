module include.runtime;

version(unittest) {
    import unit_threaded;
    import include.test_util;
}

void run(string[] args) {
    import std.stdio: File;
    const inputFileName = args[1];
    const outputFileName = args[2];
    return preprocess!File(inputFileName, outputFileName);
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
