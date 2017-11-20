module include.clang;

import clang.c.Index: CXTranslationUnit_Flags;


auto parse(in string fileName,
           in CXTranslationUnit_Flags options = CXTranslationUnit_Flags.detailedPreprocessingRecord)
    @trusted
{

    import clang.Index: Index;
    import clang.TranslationUnit: _TranslationUnit = TranslationUnit;
    import clang.Compiler: Compiler;
    import clang.c.Index: CXTranslationUnit_Flags;
    import dstep.Configuration: Configuration;
    import std.algorithm: map;
    import std.array: array;

    auto index = Index(false, false);
    Configuration config;
    Compiler compiler;
    const args = compiler.extraIncludePaths.map!(a => "-I" ~ a).array ~ "/usr/include";
    auto translationUnit = _TranslationUnit.parse(index,
                                                  fileName,
                                                  args,
                                                  compiler.extraHeaders,
                                                  options);

    void enforceCompiled () {
        import clang.c.Index: CXDiagnosticSeverity;
        import std.array : Appender;
        import std.exception : enforce;

        bool translate = true;
        auto message = Appender!string();

        foreach (diag ; translationUnit.diagnostics)
        {
            auto severity = diag.severity;

            with (CXDiagnosticSeverity)
                if (translate)
                    translate = !(severity == error|| severity == fatal);

            message.put(diag.format);
            message.put("\n");
        }

        enforce(translate, message.data);
    }


    enforceCompiled;

    return translationUnit;
}
