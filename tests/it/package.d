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
        import dpp.runtime.app: realRun = run;
        import std.algorithm: map;
        import std.array: array;

        const baseLineArgs = [
            "d++",
            "--include-path",
            sandboxPath
        ];
        auto options = Options(baseLineArgs ~ args);
        options.dppFileNames[] = options.dppFileNames.map!(a => sandbox.inSandboxPath(a)).array;

        realRun(options);
    }

    void runPreprocessOnly(string[] args...) @safe const {
        run("--preprocess-only" ~ args);
    }

    void shouldCompile(string file = __FILE__, size_t line = __LINE__)
                      (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldSucceed!(file, line)(["dmd", "-o-", "-c"] ~ srcFiles);
        catch(Exception e)
            adjustMessage(e, srcFiles);
    }

    void shouldNotCompile(string file = __FILE__, size_t line = __LINE__)
                         (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldFail!(file, line)(["dmd", "-o-", "-c"] ~ srcFiles);
        catch(Exception e)
            adjustMessage(e, srcFiles);
    }

    void shouldCompileAndRun(string file = __FILE__, size_t line = __LINE__)
                            (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldSucceed!(file, line)(["dmd", "-run"] ~ srcFiles);
        catch(Exception e)
            adjustMessage(e, srcFiles);
    }

    void shouldCompileButNotLink(string file = __FILE__, size_t line = __LINE__)
                                (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldSucceed!(file, line)(["dmd", "-c", "-ofblob.o"] ~ srcFiles);
        catch(Exception e)
            adjustMessage(e, srcFiles);

        shouldFail("dmd", "-ofblob", "blob.o");
    }

    void adjustMessage(Exception e, in string[] srcFiles) @safe const {
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
                  .join("\n")
                )
            .join("\n\n"), e.file, e.line);

    }
}

/**
   Convenience function in the typical case that a test has a C
   header and a D main file.
*/
void shouldCompile(string file = __FILE__, size_t line = __LINE__)
                  (in C header, in D app)
{
    shouldCompile!(file, line)("hdr.h", header.code, app);
}

/**
   Convenience function in the typical case that a test has a C
   header and a D main file.
*/
void shouldCompile(string file = __FILE__, size_t line = __LINE__)
                  (in Cpp header, in D app)
{
    shouldCompile!(file, line)("hdr.hpp", header.code, app);
}


private void shouldCompile(string file = __FILE__, size_t line = __LINE__)
                          (in string headerFileName, in string headerText, in D app)
{
    with(const IncludeSandbox()) {
        writeFile(headerFileName, headerText );
        // take care of including the header and putting the D
        // code in a function
        const dCode = `#include "` ~ inSandboxPath(headerFileName) ~ `"` ~ "\n" ~
            `void main() {` ~ "\n" ~ app.code ~ "\n}\n";

        writeFile("app.dpp", dCode);
        runPreprocessOnly("app.dpp");
        shouldCompile!(file, line)("app.d");
    }
}

void shouldNotCompile(string file = __FILE__, size_t line = __LINE__)
                  (in C header, in D app)
{
    with(const IncludeSandbox()) {
        writeFile("hdr.h", header.code);
        // take care of including the header and putting the D
        // code in a function
        const dCode = `#include "` ~ inSandboxPath("hdr.h") ~ `"` ~ "\n" ~
            `void main() {` ~ "\n" ~ app.code ~ "\n}\n";

        writeFile("app.dpp", dCode);
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
                        (in C header, in C source, in D app, in RuntimeArgs args = RuntimeArgs())
{
    import std.process: environment;

    with(const IncludeSandbox()) {
        writeFile("hdr.h", header.code);
        const includeLine = `#include "` ~ inSandboxPath("hdr.h") ~ `"` ~ "\n";
        const cSource = includeLine ~ source.code;
        writeFile("c.c", cSource);

        const compiler = "gcc";

        shouldSucceed(compiler, "-g", "-c", "c.c");

        // take care of including the header and putting the D
        // code in a function
        const dCode = includeLine ~
            `void main() {` ~ "\n" ~ app.code ~ "\n}\n";

        writeFile("app.dpp", dCode);
        runPreprocessOnly("app.dpp");

        try
            shouldSucceed!(file, line)(["dmd", "-g", "app.d", "c.o"]);
        catch(Exception e)
            adjustMessage(e, ["app.d"]);

        try
            shouldSucceed!(file, line)(["./app"] ~ args.args);
        catch(Exception e)
            adjustMessage(e, ["app.d"]);
    }
}

/**
   Convenience function in the typical case that a test has a C
   header and a D main file.
*/
void shouldCompileAndRun(string file = __FILE__, size_t line = __LINE__)
                        (in Cpp header, in Cpp source, in D app, in RuntimeArgs args = RuntimeArgs())
{
    import std.process: environment;

    with(const IncludeSandbox()) {
        writeFile("hdr.hpp", header.code);
        const includeLine = `#include "` ~ inSandboxPath("hdr.hpp") ~ `"` ~ "\n";
        const cppSource = includeLine ~ source.code;
        writeFile("cpp.cpp", cppSource);

        const compiler = environment.get("TRAVIS", "") == ""
            ? "g++"
            : "g++-7";

        shouldSucceed(compiler, "-g", "-std=c++17", "-c", "cpp.cpp");

        // take care of including the header and putting the D
        // code in a function
        const dCode = includeLine ~
            `void main() {` ~ "\n" ~ app.code ~ "\n}\n";

        writeFile("app.dpp", dCode);
        runPreprocessOnly("app.dpp");

        try
            shouldSucceed!(file, line)(["dmd", "-g", "app.d", "cpp.o", "-L-lstdc++"]);
        catch(Exception e)
            adjustMessage(e, ["app.d"]);

        try
            shouldSucceed!(file, line)(["./app"] ~ args.args);
        catch(Exception e)
            adjustMessage(e, ["app.d"]);
    }
}
