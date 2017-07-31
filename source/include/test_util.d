module include.test_util;

version(unittest):


struct TestFile {

    string fileName;
    string mode;
    string[] lines;
    string currentOutputLine;
    static TestFile[string] inputFiles;
    static TestFile[string] outputFiles;

    static void writeFile(in string fileName, string[] input) @safe {
        inputFiles[fileName] = TestFile();
        inputFiles[fileName].lines = input;
    }

    static string[] output(in string fileName) @safe {
        import std.exception: enforce;
        enforce(fileName in outputFiles, "No output file named " ~ fileName);
        return outputFiles[fileName].lines;
    }

    static bool exists(in string fileName) @safe @nogc nothrow {
        return fileName in inputFiles || fileName in outputFiles;
    }

    this(in string fileName, in string mode = "r") @safe {

        this.fileName = fileName;
        this.mode = mode;

        switch(mode) {
        default:
            throw new Exception("Unknown file mode: " ~ mode);
        case "r":
            lines = inputFiles[fileName].lines;
            break;
        case "w":
            outputFiles[fileName] = this;
            break;
        }
    }

    void write(T...)(auto ref T args) {
        import std.conv: text;
        import std.functional: forward;
        import std.string: splitLines;
        import std.algorithm: canFind, endsWith;

        currentOutputLine ~= text(forward!args);

        if(currentOutputLine.canFind("\n")) {

            auto newLines = currentOutputLine.splitLines;
            lines ~= newLines[0 .. $ - 1];

            if(currentOutputLine.endsWith("\n")) {
                currentOutputLine = "";
                lines ~= newLines[$ - 1];
            } else
                currentOutputLine = newLines[$ - 1];
        }

        if(mode == "w") outputFiles[fileName].lines = lines;
    }

    void writeln(T...)(auto ref T args) {
        write(args, "\n");
    }

    bool exists() @safe @nogc pure nothrow const {
        return true;
    }

    inout(string)[] byLine() @safe @nogc pure nothrow inout {
        return lines;
    }
}
