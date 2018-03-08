/**
   Code to make the executable do what it does at runtime.
 */
module include.runtime;

/**
   The "real" main
 */
void run(string[] args) @safe {
    import std.stdio: File;
    const inputFileName = args[1];
    const outputFileName = args[2];
    return preprocess!File(inputFileName, outputFileName);
}

/**
   Preprocesses a quasi-D file, expanding #include directives inline while
   translating all definitions, and redefines any macros defined therein.

   The output is a valid D file that can be compiled.

   Params:
        inputFileName = The name of the input file.
        outputFileName = The name of the output file.
 */
void preprocess(File)(in string inputFileName, in string outputFileName) {

    import include.expansion: maybeExpand;
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
        outputFile.writeln("import core.stdc.stdarg: va_list;");
        outputFile.writeln("#define __gnuc_va_list va_list");

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
