/**
   Integration tests.
 */
module it;

public import unit_threaded;
import unit_threaded.integration;

version(Windows)
        enum objectFileExtension = ".obj";
else
        enum objectFileExtension = ".o";

version(dpp2)
    alias WIP2 = ShouldFail;
else
    enum WIP2;


mixin template shouldCompile(D dCode) {
    import std.traits: getUDAs;
    enum udasC = getUDAs!(__traits(parent, {}), C);
    void verify() {
        .shouldCompile(udasC[0], dCode);
    }
}

string shouldCompile(in D dCode) {
    return `mixin shouldCompile!(D(q{` ~ dCode.code ~ `})); verify;`;
}


/// C code
struct C {
    string code;
}

/// C++ code
struct Cpp {
    string code;
}

/// D code
struct D {
    string code;
}

struct RuntimeArgs {
    string[] args;
}

struct IncludeSandbox {

    alias sandbox this;

    Sandbox sandbox;

    static auto opCall() @safe {
        IncludeSandbox ret;
        ret.sandbox = Sandbox();
        return ret;
    }

    void run(string[] args...) @safe const {
        import dpp.runtime.options: Options;
        import dpp.runtime.app: dppRun = run;
        import std.algorithm: map;
        import std.array: array;
        import std.process: environment;

        const baseLineArgs = [
            "d++",
            "--include-path",
            sandboxPath,
            "--compiler",
            environment.get("DC", "dmd"),
        ];
        auto options = Options(baseLineArgs ~ args);
        options.dppFileNames[] = options.dppFileNames.map!(a => sandbox.inSandboxPath(a)).array;

        dppRun(options);
    }

    void runPreprocessOnly(in string[] args...) @safe const {
        run(["--preprocess-only", "--keep-pre-cpp-files"] ~ args);
        version(Windows) {
            // Windows tests would sometimes fail saying the D modules
            // don't exist... I didn't prove it, but my suspicion is
            // just an async write hasn't completed yet. This sleep, while
            // a filthy hack, worked consistently for me.
            import core.thread : Thread, msecs;
            () @trusted { Thread.sleep(500.msecs); }();
        }
    }

    void shouldCompile(string file = __FILE__, size_t line = __LINE__)
                      (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldSucceed!(file, line)([dCompiler, "-m64", "-o-", "-c"] ~ srcFiles);
        catch(Exception e)
            adjustMessage(e, srcFiles);
    }

    void shouldNotCompile(string file = __FILE__, size_t line = __LINE__)
                         (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldFail!(file, line)([dCompiler, "-m64", "-o-", "-c"] ~ srcFiles);
        catch(Exception e)
            adjustMessage(e, srcFiles);
    }

    void shouldCompileButNotLink(string file = __FILE__, size_t line = __LINE__)
                                (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldSucceed!(file, line)([dCompiler, "-c", "-ofblob" ~ objectFileExtension] ~ srcFiles);
        catch(Exception e)
            adjustMessage(e, srcFiles);

        shouldFail(dCompiler, "-ofblob", "blob" ~ objectFileExtension);
    }

    private void adjustMessage(Exception e, in string[] srcFiles) @safe const {
        import std.algorithm: map;
        import std.array: join;
        import std.file: readText;
        import std.string: splitLines;
        import std.range: enumerate;
        import std.format: format;

        throw new UnitTestException(
            "\n\n" ~ e.msg ~ "\n\n" ~ srcFiles
            .map!(a => a ~ ":\n----------\n" ~ readText(sandbox.inSandboxPath(a))
                  .splitLines
                  .enumerate(1)
                  .map!(b => format!"%5d:   %s"(b[0], b[1]))
                  .dropPreamble
                  .join("\n")
                )
            .join("\n\n"), e.file, e.line);
    }

    private string includeLine(in string headerFileName) @safe pure nothrow const {
        return `#include "` ~ inSandboxPath(headerFileName) ~ `"`;
    }

    void writeHeaderAndApp(in string headerFileName, in string headerText, in D app) @safe const {
        writeFile(headerFileName, headerText);
        // take care of including the header and putting the D
        // code in a function
        const dCode =
            includeLine(headerFileName) ~ "\n" ~
            `void main() {` ~ "\n" ~ app.code ~ "\n}\n";
        writeFile("app.dpp", dCode);
    }
}

private auto dropPreamble(R)(R lines) {
    import dpp.runtime.app: preamble;
    import std.array: array;
    import std.range: walkLength, drop;
    import std.string: splitLines;

    const length = lines.save.walkLength;
    const preambleLength = preamble.splitLines.length + 1;

    return length > preambleLength ? lines.drop(preambleLength).array : lines.array;
}

/**
   Convenience function in the typical case that a test has a C
   header and a D main file.
*/
void shouldCompile(string file = __FILE__, size_t line = __LINE__)
                  (in C header, in D app, in string[] cmdLineArgs = [])
{
    shouldCompile!(file, line)("hdr.h", header.code, app, cmdLineArgs);
}

/**
   Convenience function in the typical case that a test has a C
   header and a D main file.
*/
void shouldCompile(string file = __FILE__, size_t line = __LINE__)
                  (in Cpp header, in D app, in string[] cmdLineArgs = [])
{
    shouldCompile!(file, line)("hdr.hpp", header.code, app, cmdLineArgs);
}


private void shouldCompile(string file = __FILE__, size_t line = __LINE__)
                          (in string headerFileName,
                           in string headerText,
                           in D app,
                           in string[] cmdLineArgs = [])
{
    with(const IncludeSandbox()) {
        writeHeaderAndApp(headerFileName, headerText, app);
        runPreprocessOnly(cmdLineArgs ~ "app.dpp");
        shouldCompile!(file, line)("app.d");
    }
}

void shouldNotCompile(string file = __FILE__, size_t line = __LINE__)
                  (in C header, in D app)
{
    with(const IncludeSandbox()) {
        writeHeaderAndApp("hdr.h", header.code, app);
        runPreprocessOnly("app.dpp");
        shouldNotCompile!(file, line)("app.d");
    }
}


alias shouldRun = shouldCompileAndRun;

/**
   Convenience function in the typical case that a test has a C
   header and a D main file.
*/
void shouldCompileAndRun(string file = __FILE__, size_t line = __LINE__)
                        (in C header, in C cSource, in D app, in RuntimeArgs args = RuntimeArgs())
{
    shouldCompileAndRun!(file, line)("hdr.h", header.code, "c.c", cSource.code, app, args);
}

/**
   Convenience function in the typical case that a test has a C
   header and a D main file.
*/
void shouldCompileAndRun(string file = __FILE__, size_t line = __LINE__)
                        (in Cpp header, in Cpp cppSource, in D app, in RuntimeArgs args = RuntimeArgs())
{
    shouldCompileAndRun!(file, line)("hdr.hpp", header.code, "cpp.cpp", cppSource.code, app, args);
}


private void shouldCompileAndRun
    (string file = __FILE__, size_t line = __LINE__)
    (
        in string headerFileName,
        in string headerText,
        in string cSourceFileName,
        in string cText, in D app,
        in RuntimeArgs args = RuntimeArgs(),
    )
{
    import std.process: environment;

    with(const IncludeSandbox()) {
        writeHeaderAndApp(headerFileName, headerText, app);
        writeFile(cSourceFileName, includeLine(headerFileName) ~ cText);

        const isCpp = headerFileName == "hdr.hpp";
        const compilerName = () {
            if(environment.get("TRAVIS", "") == "")
                return isCpp ? "clang++" : "clang";
            else
                return isCpp ? "g++" : "gcc";
        }();
        const compiler = compilerName;
        const languageStandard =  isCpp ? "-std=c++17" : "-std=c11";
        const outputFileName = "c" ~ objectFileExtension;

        shouldSucceed(compiler, "-o", outputFileName, "-g", languageStandard, "-c", cSourceFileName);
        shouldExist(outputFileName);

        runPreprocessOnly("app.dpp");

        version(Windows)
            // stdc++ is GNU-speak, on Windows, it uses the Microsoft lib
            const string[] linkStdLib = [];
        else
            const linkStdLib = isCpp ? ["-L-lstdc++"] : [];

        try
            shouldSucceed!(file, line)([dCompiler, "-m64", "-g", "app.d", "c" ~ objectFileExtension] ~ linkStdLib);
        catch(Exception e)
            adjustMessage(e, ["app.d"]);

        try
            shouldSucceed!(file, line)(["./app"] ~ args.args);
        catch(Exception e)
            adjustMessage(e, ["app.d"]);
    }
}


private string dCompiler() @safe {
    import std.process: environment;
    return environment.get("DC", "dmd");
}
