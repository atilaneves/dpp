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
    bool keepTempFile;
    bool earlyExit;

    this(string[] args) {

        import clang: systemPaths;
        import std.exception: enforce;
        import std.getopt: getopt, defaultGetoptPrinter;
        import std.path: stripExtension;

        auto helpInfo =
            getopt(args,
                   "debug|d", "Print debug information", &debugOutput,
                   "i|clang-include-path", "Include paths", &includePaths,
                   "keep-tmp-file", "Do not delete the temporary pre-preprocessed file", &keepTempFile,
        );

        const usage = "Usage: include <inFile> [outFile]";

        if(helpInfo.helpWanted) {
            () @trusted {
                defaultGetoptPrinter(usage, helpInfo.options);
            }();
            earlyExit = true;
        }

        enforce(args.length == 2 || args.length == 3, usage);

        inputFileName = args[1];
        outputFileName = args.length == 3 ? args[2] : args[1].stripExtension ~ ".d";

        includePaths = systemPaths ~ includePaths;
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
