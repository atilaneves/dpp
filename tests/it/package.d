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

    void expand(in Out out_,
                in In in_,
                in string[] inLines,
                in string file = __FILE__,
                in size_t line = __LINE__)
        @safe const
    {
        import std.array: join;
        expand(out_, in_, inLines.join("\n"), file, line);
    }

    void expand(in Out out_,
                in In in_,
                in string inText,
                in string file = __FILE__,
                in size_t line = __LINE__)
        @safe const
    {
        import dpp.runtime.context: Context;
        import dpp.expansion: realExpand = expand;

        const outFileName = inSandboxPath(out_.value);
        const inFileName = inSandboxPath(in_.value);
        writeFile(inFileName, inText);
        Context context;
        context.options.includePaths = [sandboxPath];
        realExpand(inFileName, context, file, line);
        writeFile(outFileName, context.translation);
    }

    void run(string[] args...) @safe const {
        import dpp.runtime.options: Options;
        import dpp.runtime.app: realRun = run;

        const baseLineArgs = [
            "d++",
            "--preprocess-only",
            "--clang-include-path",
            sandboxPath
        ];
        auto options = Options(baseLineArgs ~ args);
        options.dppFileName = inSandboxPath(options.dppFileName);
        options.dFileName = inSandboxPath(options.dFileName);

        realRun(options);
    }

    void runPreprocessOnly(string[] args...) @safe const {
        import dpp.runtime.options: Options;
        import dpp.runtime.app: realRun = run;

        const baseLineArgs = [
            "d++",
            "--preprocess-only",
            "--clang-include-path",
            sandboxPath
        ];
        auto options = Options(baseLineArgs ~ args);
        options.dppFileName = inSandboxPath(options.dppFileName);
        options.dFileName = inSandboxPath(options.dFileName);

        realRun(options);
    }

    void preprocess(in string dppFileName, in string dFileName) @safe const {
        import dpp.runtime.options: Options;
        import dpp.runtime.app: realPreProcess = preprocess;
        import std.stdio: File;

        auto options = Options(
            [
                "./include",
                "--preprocess-only",
                "--clang-include-path",
                sandboxPath,
                inSandboxPath(dppFileName),
            ]
        );

        realPreProcess!File(options);
    }

    void shouldCompile(string file = __FILE__, size_t line = __LINE__)
                      (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldSucceed!(file, line)(["dmd", "-o-", "-c"] ~ srcFiles);
        catch(Exception e) {
            adjustMessage(e, srcFiles);
        }
    }

    void shouldNotCompile(string file = __FILE__, size_t line = __LINE__)
                         (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldFail!(file, line)(["dmd", "-o-", "-c"] ~ srcFiles);
        catch(Exception e) {
            adjustMessage(e, srcFiles);
        }
    }

    void shouldCompileAndRun(string file = __FILE__, size_t line = __LINE__)
                            (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldSucceed!(file, line)(["dmd", "-run"] ~ srcFiles);
        catch(Exception e) {
            adjustMessage(e, srcFiles);
        }
    }

    void shouldCompileButNotLink(string file = __FILE__, size_t line = __LINE__)
                                (in string[] srcFiles...)
        @safe const
    {
        try
            sandbox.shouldSucceed!(file, line)(["dmd", "-c", "-ofblob.o"] ~ srcFiles);
        catch(Exception e) {
            adjustMessage(e, srcFiles);
        }

        shouldFail("dmd", "-ofblob", "blob.o");
    }

    void adjustMessage(Exception e, in string[] srcFiles) @safe const {
        import std.algorithm: map;
        import std.array: join;
        import std.file: readText;

        throw new UnitTestException(
            "\n\n" ~ e.msg ~ "\n\n" ~ srcFiles
            .map!(a => a ~ ":\n----------\n" ~ readText(sandbox.inSandboxPath(a)))
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
    with(const IncludeSandbox()) {
        writeFile("hdr.h", header.code);
        // take care of including the header and putting the D
        // code in a function
        const dCode = `#include "` ~ inSandboxPath("hdr.h") ~ `"` ~ "\n" ~
            `void main() {` ~ "\n" ~ app.code ~ "\n}\n";

        writeFile("app.dpp", dCode);
        runPreprocessOnly("app.dpp");
        shouldCompile!(file, line)("app.d");
    }
}

/**
   Convenience function in the typical case that a test has a C
   header and a D main file.
*/
void shouldCompile(string file = __FILE__, size_t line = __LINE__)
                  (in Cpp header, in D app)
{
    with(const IncludeSandbox()) {
        writeFile("hdr.hpp", header.code);
        // take care of including the header and putting the D
        // code in a function
        const dCode = `#include "` ~ inSandboxPath("hdr.hpp") ~ `"` ~ "\n" ~
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

        shouldSucceed(compiler, "-c", "c.c");

        // take care of including the header and putting the D
        // code in a function
        const dCode = includeLine ~
            `void main() {` ~ "\n" ~ app.code ~ "\n}\n";

        writeFile("app.dpp", dCode);
        runPreprocessOnly("app.dpp");

        try
            shouldSucceed!(file, line)(["dmd", "app.d", "c.o"]);
        catch(Exception e)
            adjustMessage(e, ["app.d"]);

        shouldSucceed!(file, line)(["./app"] ~ args.args);
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

        shouldSucceed(compiler, "-std=c++17", "-c", "cpp.cpp");

        // take care of including the header and putting the D
        // code in a function
        const dCode = includeLine ~
            `void main() {` ~ "\n" ~ app.code ~ "\n}\n";

        writeFile("app.dpp", dCode);
        runPreprocessOnly("app.dpp");

        try
            shouldSucceed!(file, line)(["dmd", "app.d", "cpp.o"]);
        catch(Exception e)
            adjustMessage(e, ["app.d"]);

        shouldSucceed!(file, line)(["./app"] ~ args.args);
    }
}
