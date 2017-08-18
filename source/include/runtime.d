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

    import include.translation: maybeExpand;
    import std.algorithm: map, startsWith;
    import std.process: execute;
    import std.exception: enforce;
    import std.conv: text;
    import std.string: splitLines;
    import std.file: remove;

    const tmpFileName = outputFileName ~ ".tmp";
    scope(exit) remove(tmpFileName);

    {
        auto outputFile = File(tmpFileName, "w");

        outputFile.writeln("import core.stdc.config;");

        () @trusted {
            foreach(line; File(inputFileName).byLine.map!(a => cast(string)a)) {
                outputFile.writeln(line.maybeExpand);
            }
        }();
    }


    const ret = execute(["cpp", tmpFileName]);
    enforce(ret.status == 0, text("Could not run cpp:\n", ret.output));

    {
        auto outputFile = File(outputFileName, "w");

        foreach(line; ret.output.splitLines) {
            if(!line.startsWith("#"))
                outputFile.writeln(line);
        }
    }
}
