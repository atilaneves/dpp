/**
   Code to make the executable do what it does at runtime.
 */
module include.runtime.app;

import include.from;

/**
   The "real" main
 */
void run(in from!"include.runtime.options".Options options) @safe {
    import std.stdio: File;
    preprocess!File(options);
}


/**
   Preprocesses a quasi-D file, expanding #include directives inline while
   translating all definitions, and redefines any macros defined therein.

   The output is a valid D file that can be compiled.

   Params:
        options = The runtime options.
 */
void preprocess(File)(in from!"include.runtime.options".Options options) {

    import include.expansion: maybeExpand;
    import std.algorithm: map, startsWith;
    import std.process: execute;
    import std.exception: enforce;
    import std.conv: text;
    import std.string: splitLines;
    import std.file: remove;

    const tmpFileName = options.outputFileName ~ ".tmp";
    scope(exit) remove(tmpFileName);

    {
        auto outputFile = File(tmpFileName, "w");

        outputFile.writeln("import core.stdc.config;");
        outputFile.writeln("import core.stdc.stdarg: va_list;");
        outputFile.writeln("struct __locale_data { int dummy; } // FIXME");
        outputFile.writeln("#define __gnuc_va_list va_list");

        () @trusted {
            foreach(line; File(options.inputFileName).byLine.map!(a => cast(string)a)) {
                outputFile.writeln(line.maybeExpand(options));
            }
        }();
    }


    const ret = execute(["cpp", tmpFileName]);
    enforce(ret.status == 0, text("Could not run cpp on ", tmpFileName, ":\n", ret.output));

    {
        auto outputFile = File(options.outputFileName, "w");

        foreach(line; ret.output.splitLines) {
            if(!line.startsWith("#"))
                outputFile.writeln(line);
        }
    }
}
