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
    string[] includePaths;
    bool earlyExit;

    this(string[] args) {

        import std.exception: enforce;
        import std.getopt: getopt, defaultGetoptPrinter;

        auto helpInfo = getopt(args,
               "debug|d", "Print debug information", &debugOutput,
               "i", "Include paths", &includePaths,
        );

        if(helpInfo.helpWanted) {
            () @trusted {
                defaultGetoptPrinter("Usage: reggae -b <ninja|make|binary|tup> </path/to/project>",
                                     helpInfo.options);
            }();
            earlyExit = true;
        }

        enforce(args.length == 3, "Usage: include <inFile> <outFile>");

        inputFileName = args[1];
        outputFileName = args[2];
        includePaths = "/usr/include" ~ includePaths;
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
        ret.includePaths = includePaths.dup;
        return ret;
    }

    void log(T...)(auto ref T args) @trusted const {
        version(unittest) import unit_threaded.io: writeln = writelnUt;
        else import std.stdio: writeln;

        version(unittest) enum shouldLog = true;
        else             const shouldLog = debugOutput;

        if(shouldLog)
            debug writeln(indentation, args);
    }
}
