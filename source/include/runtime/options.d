/**
   Command-line options
 */
module include.runtime.options;

@safe:

struct Options {

    enum usage = "Usage: d++ [d++ options] [D compiler options] <filename.dpp> [D compiler args]";

    string inputFileName;
    string outputFileName;
    string indentation;
    bool debugOutput;
    string[] includePaths;
    bool keepPreCppFile;
    bool keepDlangFile;
    bool preprocessOnly;
    string dlangCompiler = "dmd";
    string[] dlangCompilerArgs;
    bool earlyExit;

    this(string[] args) {

        import clang: systemPaths;
        import std.exception: enforce;
        import std.getopt: getopt, defaultGetoptPrinter, config;
        import std.path: stripExtension, extension, buildPath, absolutePath;
        import std.file: tempDir;
        import std.algorithm: find, filter;
        import std.array: array;
        import std.conv: text;

        auto helpInfo =
            getopt(
                args,
                config.passThrough,
                "debug|d", "Print debug information", &debugOutput,
                "i|clang-include-path", "Include paths", &includePaths,
                "keep-pre-cpp-file", "Do not delete the temporary pre-preprocessed file", &keepPreCppFile,
                "keep-d-file", "Do not delete the temporary D file to be compiled", &keepDlangFile,
                "preprocess-only", "Only transform the .dpp file into a .d file, don't compile", &preprocessOnly,
                "d-file-name", "D output file name (defaults to replacing .dpp with .d)", &outputFileName,
                "compiler", "D compiler to use", &dlangCompiler,
            );

        if(helpInfo.helpWanted) {
            () @trusted {
                defaultGetoptPrinter(usage, helpInfo.options);
            }();
            earlyExit = true;
            return;
        }

        if(preprocessOnly)
            enforce(args.length == 2,
                    text("Wrong argument length. Expected 2, got ", args.length,
                         " for preprocessing only.\n", usage));
        else
            enforce(args.length >= 2, "Not enough arguments\n" ~ usage);

        auto fromInput = args.find!(a => a.extension == ".dpp");
        enforce(fromInput.length != 0, "No .dpp input file specified\n" ~ usage);
        inputFileName = fromInput[0];

        // By default, use the same name as the .dpp file with a .d extension.
        // If running as a compiler wrapper however, we don't want to see the resulting
        // .d file unless explicitly setting it via the command-line, so we hide it
        // away in a temporary directory
        if(outputFileName == "") {
            outputFileName = inputFileName.stripExtension ~ ".d";
            if(!preprocessOnly) outputFileName = buildPath(tempDir, outputFileName.absolutePath);
        } else
            keepDlangFile = true;

        // Remove the name of this binary and the name of the .dpp input file from args
        // so that a D compiler can use the remaining entries.
        dlangCompilerArgs = args[1..$].filter!(a => a != inputFileName).array ~ outputFileName;

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
