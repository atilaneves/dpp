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

    string[] dppFileNames;
    string indentation;
    bool debugOutput;
    string[] includePaths;
    bool keepPreCppFiles;
    bool keepDlangFiles;
    bool parseAsCpp;
    bool preprocessOnly;
    string dlangCompiler = "dmd";
    string[] dlangCompilerArgs;
    string[] defines;
    bool earlyExit;
    bool hardFail;
    bool cppStdLib;

    this(string[] args) {

        import clang: systemPaths;
        import std.exception: enforce;
        import std.path: stripExtension, extension, buildPath, absolutePath;
        import std.file: tempDir;
        import std.algorithm: map, filter, canFind, startsWith;
        import std.array: array;
        import std.conv: text;

        parseArgs(args);
        if(earlyExit) return;

        if(preprocessOnly)
            keepDlangFiles = true;

        dppFileNames = args.filter!(a => a.extension == ".dpp").array;
        enforce(dppFileNames.length != 0, "No .dpp input file specified\n" ~ usage);

        // Remove the name of this binary and the name of the .dpp input file from args
        // so that a D compiler can use the remaining entries.
        dlangCompilerArgs =
            args[1..$].filter!(a => a.extension != ".dpp").array ~
            dFileNames;

        // if no -of option is given, default to the name of the .dpp file
        if(!dlangCompilerArgs.canFind!(a => a.startsWith("-of")) && !dlangCompilerArgs.canFind("-c"))
            dlangCompilerArgs ~= "-of" ~
                args.
                filter!(a => a.extension == ".dpp" || a.extension == ".d")
                .front
                .stripExtension
                ~ exeExtension;

        version(Windows)
            assert(!cppStdLib, "C++ std lib functionality not implemented yet for Windows");

        if(cppStdLib) {
            dlangCompilerArgs ~= "-L-lstdc++";
            parseAsCpp = true;
        }

        includePaths = systemPaths ~ includePaths;
    }

    string[] dFileNames() @safe pure const {
        import std.algorithm: map;
        import std.array: array;
        return dppFileNames.map!toDFileName.array;
    }

    static string toDFileName(in string dppFileName) @safe pure nothrow {
        import std.path: stripExtension;
        return dppFileName.stripExtension ~ ".d";
    }

    private void parseArgs(ref string[] args) {
        import std.getopt: getopt, defaultGetoptPrinter, config;
        auto helpInfo =
            getopt(
                args,
                config.passThrough,
                "print-cursors", "Print debug information", &debugOutput,
                "include-path", "Include paths", &includePaths,
                "keep-pre-cpp-files", "Do not delete the temporary pre-preprocessed file", &keepPreCppFiles,
                "keep-d-files", "Do not delete the temporary D file to be compiled", &keepDlangFiles,
                "preprocess-only", "Only transform the .dpp file into a .d file, don't compile", &preprocessOnly,
                "compiler", "D compiler to use", &dlangCompiler,
                "parse-as-cpp", "Parse header as C++", &parseAsCpp,
                "define", "C Preprocessor macro", &defines,
                "hard-fail", "Translate nothing if any part fails", &hardFail,
                "c++-std-lib", "Link to the C++ standard library", &cppStdLib,
            );

        if(helpInfo.helpWanted) {
            () @trusted {
                defaultGetoptPrinter(usage, helpInfo.options);
            }();
            earlyExit = true;
        }
    }

    Options indent() pure nothrow const {
        Options ret;
        foreach(i, ref elt; ret.tupleof) {
            static if(__traits(compiles, this.tupleof[i].dup))
                elt = this.tupleof[i].dup;
            else
                elt = this.tupleof[i];
        }

        ret.includePaths = includePaths.dup;
        ret.defines = defines.dup;
        ret.indentation = indentation ~ "    ";

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
