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
        import std.path: stripExtension;

        auto helpInfo = getopt(args,
               "debug|d", "Print debug information", &debugOutput,
               "i", "Include paths", &includePaths,
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


string[] systemPaths() @safe {
    import std.process: execute;
    import std.string: splitLines, stripLeft;
    import std.algorithm: map, countUntil;
    import std.array: array;

    const res = execute(["gcc", "-v", "-xc", "/dev/null", "-fsyntax-only"]);
    if(res.status != 0) throw new Exception("Failed to call gcc:\n" ~ res.output);

    auto lines = res.output.splitLines;

    const startIndex = lines.countUntil("#include <...> search starts here:") + 1;
    assert(startIndex > 0);
    const endIndex = lines.countUntil("End of search list.");
    assert(endIndex > 0);

    return lines[startIndex .. endIndex].map!stripLeft.array;
}
