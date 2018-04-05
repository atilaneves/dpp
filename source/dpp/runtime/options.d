/**
   Command-line options
 */
module dpp.runtime.options;

@safe:

version(Windows)
    enum exeExtension = ".exe";
else
    enum exeExtension = "";


struct Options {

    enum usage = "Usage: d++ [options] [D compiler options] <filename.dpp> [D compiler args]";

    string dppFileName;
    string dFileName;
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
        import std.path: stripExtension, extension, buildPath, absolutePath;
        import std.file: tempDir;
        import std.algorithm: find, filter, canFind, startsWith;
        import std.array: array;
        import std.conv: text;

        parseArgs(args);
        if(earlyExit) return;

        if(preprocessOnly)
            enforce(args.length == 2,
                    text("Wrong argument length. Expected 2, got ", args.length,
                         " for preprocessing only.\n", usage));
        else
            enforce(args.length >= 2, "Not enough arguments\n" ~ usage);

        auto fromInput = args.find!(a => a.extension == ".dpp");
        enforce(fromInput.length != 0, "No .dpp input file specified\n" ~ usage);
        dppFileName = fromInput[0];

        enforce(args.filter!(a => a.extension == ".dpp").array.length == 1,
                "Only one .dpp file at a time is supported currently.");

        // By default, use the same name as the .dpp file with a .d extension.
        // If running as a compiler wrapper however, we don't want to see the resulting
        // .d file unless explicitly setting it via the command-line, so we hide it
        // away in a temporary directory
        if(dFileName == "") {
            dFileName = dppFileName.stripExtension ~ ".d";
            if(!preprocessOnly) dFileName = buildPath(tempDir, dFileName.absolutePath);
        } else
            keepDlangFile = true;

        // Remove the name of this binary and the name of the .dpp input file from args
        // so that a D compiler can use the remaining entries.
        dlangCompilerArgs = args[1..$].filter!(a => a != dppFileName).array ~ dFileName;

        // if no -of option is given, default to the name of the .dpp file
        if(!dlangCompilerArgs.canFind!(a => a.startsWith("-of")))
            dlangCompilerArgs ~= "-of" ~ dppFileName.stripExtension ~ exeExtension;

        includePaths = systemPaths ~ includePaths;
    }

    private void parseArgs(ref string[] args) {
        import std.getopt: getopt, defaultGetoptPrinter, config;
        auto helpInfo =
            getopt(
                args,
                config.passThrough,
                "debug|d", "Print debug information", &debugOutput,
                "i|clang-include-path", "Include paths", &includePaths,
                "keep-pre-cpp-file", "Do not delete the temporary pre-preprocessed file", &keepPreCppFile,
                "keep-d-file", "Do not delete the temporary D file to be compiled", &keepDlangFile,
                "preprocess-only", "Only transform the .dpp file into a .d file, don't compile", &preprocessOnly,
                "d-file-name", "D output file name (defaults to replacing .dpp with .d)", &dFileName,
                "compiler", "D compiler to use", &dlangCompiler,
            );

        if(helpInfo.helpWanted) {
            () @trusted {
                defaultGetoptPrinter(usage, helpInfo.options);
            }();
            earlyExit = true;
        }
    }

    this(in string dppFileName,
         in string dFileName,
         in string indentation = "",
         in bool debugOutput = false)
    pure nothrow
    {
        this.dppFileName = dppFileName;
        this.dFileName = dFileName;
        this.indentation = indentation;
        this.debugOutput = debugOutput;
    }

    Options indent() pure nothrow const {
        auto ret = Options(dppFileName, dFileName, indentation ~ "    ", debugOutput);
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
