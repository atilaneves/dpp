/**
   Command-line options
 */
module include.runtime.options;

@safe:

struct Options {

    string inputFileName;
    string outputFileName;
    bool debugOutput;

    this(string[] args) {
        import std.exception: enforce;
        import std.getopt: getopt, defaultGetoptPrinter;

        getopt(args,
               "debug|d", "Print debug information", &debugOutput,
        );

        enforce(args.length == 3, "Usage: include <inFile> <outFile>");

        inputFileName = args[1];
        outputFileName = args[2];
    }

    this(in string inputFileName, in string outputFileName) {
        this.inputFileName = inputFileName;
        this.outputFileName = outputFileName;
    }
}
