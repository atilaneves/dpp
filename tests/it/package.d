/**
   Integration tests.
 */
module it;

public import unit_threaded;
public import unit_threaded.integration;

struct In {
    string value;
}

struct Out {
    string value;
}

struct IncludeSandbox {

    alias sandbox this;

    Sandbox sandbox;

    static auto opCall() @safe {
        IncludeSandbox ret;
        ret.sandbox = Sandbox();
        return ret;
    }

    void expand(in Out out_, in In in_, in string[] inLines, in string file = __FILE__, in size_t line = __LINE__)
        @safe const
    {
        import std.array: join;
        expand(out_, in_, inLines.join("\n"), file, line);
    }

    void expand(in Out out_, in In in_, in string inText, in string file = __FILE__, in size_t line = __LINE__)
        @safe const
    {
        import include.expansion: realExpand = expand;
        const outFileName = inSandboxPath(out_.value);
        const inFileName = inSandboxPath(in_.value);
        writeFile(inFileName, inText);
        writeFile(outFileName, realExpand(inFileName, file, line));
    }

    void preprocess(in string inputFileName, in string outputFileName) @safe {
        import include.runtime.options: Options;
        import include.runtime.app: realPreProcess = preprocess;
        import std.stdio: File;
        const options = Options(inSandboxPath(inputFileName), inSandboxPath(outputFileName));
        realPreProcess!File(options);
    }

    void shouldCompileAndRun(string file = __FILE__, size_t line = __LINE__)(in string[] srcFiles...) @safe const {
        try
            sandbox.shouldSucceed!(file, line)(["dmd", "-run"] ~ srcFiles);
        catch(Exception e) {
            adjustMessage(e, srcFiles);
            throw e;
        }
    }

    void shouldCompileButNotLink(string file = __FILE__, size_t line = __LINE__)(in string[] srcFiles...) @safe const {
        try
            sandbox.shouldSucceed!(file, line)(["dmd", "-c", "-ofblob.o"] ~ srcFiles);
        catch(Exception e) {
            adjustMessage(e, srcFiles);
            throw e;
        }

        shouldFail("dmd", "-ofblob", "blob.o");
    }

    void shouldCompile(string file = __FILE__, size_t line = __LINE__)(in string[] srcFiles...) @safe const {
        try
            sandbox.shouldSucceed!(file, line)(["dmd", "-o-", "-c"] ~ srcFiles);
        catch(Exception e) {
            adjustMessage(e, srcFiles);
            throw e;
        }
    }

    private void adjustMessage(Exception e, in string[] srcFiles) @safe const {
        import std.algorithm: map;
        import std.array: join;
        import std.file: readText;

        e.msg = e.msg ~ "\n\n" ~ srcFiles
            .map!(a => a ~ ":\n----------\n" ~ readText(sandbox.inSandboxPath(a)))
            .join("\n\n");

    }

}
