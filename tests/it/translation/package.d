/**
   Ease-of-use imports for writing integration tests for translation
 */
module it.translation;

public import include.translation;
public import unit_threaded;
public import clang: TranslationUnit, Cursor;

struct In {
    string value;
}

struct Out {
    string value;
}

struct TranslationSandbox {

    alias sandbox this;

    Sandbox sandbox;

    static auto opCall() @safe {
        TranslationSandbox ret;
        ret.sandbox = Sandbox();
        return ret;
    }

    void expand(in Out out_, in In in_, in string[] inLines, in string file = __FILE__, in size_t line = __LINE__)
        @safe const
    {
        import include.expansion: realExpand = expand;
        const outFileName = inSandboxPath(out_.value);
        const inFileName = inSandboxPath(in_.value);
        writeFile(inFileName, inLines);
        writeFile(outFileName, realExpand(inFileName, file, line));
    }

    void shouldCompileAndRun(in string[] srcFiles...) @safe const {
        shouldExecuteOk(["dmd", "-run"] ~ srcFiles);
    }
}
