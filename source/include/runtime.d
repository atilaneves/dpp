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
    import std.range: chain;

    const tmpFileName = outputFileName ~ ".tmp";
    scope(exit) remove(tmpFileName);

    string[] expandedLines;
    string[] macros;

    () @trusted {
        foreach(line; File(inputFileName).byLine) {
            expandedLines ~= line.maybeExpand(macros);
        }
    }();

    // 1st write to a temporary file that will be preprocessed
    {
        auto outputFile = File(tmpFileName, "w");

        outputFile.writeln("import core.stdc.config;");

        foreach(line; chain(macros, expandedLines))
            outputFile.writeln(line);
    }


    // FIXME: -xc++?
    const ret = execute(["clang", "-xc", "-E", tmpFileName]);
    enforce(ret.status == 0, text("Could not run cpp:\n", ret.output));

    // the preprocessor for some reason leaves in lines beginning with #,
    // so remote all of them to get a valid source file
    {
        auto outputFile = File(outputFileName, "w");

        foreach(line; ret.output.splitLines) {
            if(!line.startsWith("#"))
                outputFile.writeln(line);
        }
    }
}
