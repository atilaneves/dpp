/**
   Command-line options
 */
module include.runtime.options;

@safe:

struct Options {

    string inputFileName;
    string outputFileName;
    string indentation;
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

    this(in string inputFileName,
         in string outputFileName,
         in string indentation = "",
         in bool debugOutput = false)
    pure nothrow
    {
        this.inputFileName = inputFileName;
        this.outputFileName = outputFileName;
        this.indentation = indentation;
        this.debugOutput = debugOutput;
    }

    Options indent() pure nothrow const {
        auto ret = Options(inputFileName, outputFileName, indentation ~ "    ", debugOutput);
        return ret;
    }

    void log(T...)(auto ref T args) const {
        version(unittest) import unit_threaded.io: writeln = writelnUt;
        else import std.stdio: writeln;

        version(unittest) enum shouldLog = true;
        else             const shouldLog = debugOutput;

        debug writeln(indentation, args);
    }
}
