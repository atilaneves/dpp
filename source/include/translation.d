module include.translation;


version(unittest) {
    import unit_threaded;
    import include.test_util;
}



string translate(string line) @safe {

    const headerFileName = getHeaderFileName(line);

    return headerFileName == ""
        ? line
        : expand(headerFileName);
}


@("translate no include")
@safe unittest {
    "foo".translate.shouldEqual("foo");
    "bar".translate.shouldEqual("bar");
}


private string expand(in string headerFileName) @trusted {
    import dstep.translator.Translator: Translator;
    import clang.TranslationUnit: TranslationUnit;
    import dstep.Configuration: Configuration;
    import dstep.translator.Options: Options;

    auto translationUnit = parseTranslationUnit(headerFileName);

    Options toOptions(in Configuration config, in string inputFile) {
        import clang.Util : asAbsNormPath, setFromList;
        import std.algorithm: map;
        import std.array: array;

        Options options;

        options.inputFiles = config.inputFiles.map!(path => path.asAbsNormPath).array;
        options.inputFile = inputFile.asAbsNormPath;
        options.language = config.language;
        options.enableComments = config.enableComments;
        options.packageName = config.packageName;
        options.publicSubmodules = config.publicSubmodules;
        options.reduceAliases = config.reduceAliases;
        options.aliasEnumMembers = config.aliasEnumMembers;
        options.portableWCharT = config.portableWCharT;
        options.zeroParamIsVararg = config.zeroParamIsVararg;
        options.singleLineFunctionSignatures = config.singleLineFunctionSignatures;
        options.spaceAfterFunctionName = config.spaceAfterFunctionName;
        options.skipDefinitions = setFromList(config.skipDefinitions);
        options.skipSymbols = setFromList(config.skipSymbols);
        options.printDiagnostics = config.printDiagnostics;
        options.collisionAction = config.collisionAction;
        options.globalAttributes = config.globalAttributes;

        return options;
    }


    class MyTranslator: Translator {

        import dstep.translator.Output: Output;
        import clang.Cursor: Cursor;

        TranslationUnit _translationUnit;

        this(TranslationUnit translationUnit, Options options = Options.init) {
            super(translationUnit, options);
            _translationUnit = translationUnit;
        }

        override string translateToString() {
            return translateCursors.content;
        }

        override Output translateCursors() {

            import clang.Util: contains;

            Output result = new Output(context.commentIndex);

            bool skipDeclaration(Cursor cursor) {
                return (_translationUnit.spelling != "" &&
                        _translationUnit.file(headerFileName) != cursor.location.spelling.file)
                    || context.options.skipSymbols.contains(cursor.spelling)
                    || cursor.isPredefined;
            }

            result.singleLine("extern(C) {");

            foreach (cursor, parent; _translationUnit.cursor.allInOrder)
            {
                if (!skipDeclaration(cursor))
                {
                    translateInGlobalScope(result, cursor, parent);
                }
            }

            if (context.commentIndex)
                result.flushLocation(context.commentIndex.queryLastLocation());

            // foreach (value; deferredDeclarations.values)
            //     result.singleLine(value);

            result.singleLine("}");

            result.finalize();

            return result;

        }
    }

    Configuration config;
    auto translator = new MyTranslator(translationUnit, toOptions(config, headerFileName));
    return translator.translateToString;
}

private auto parseTranslationUnit(in string headerFileName) @trusted {

    import clang.Index: Index;
    import clang.TranslationUnit: TranslationUnit;
    import clang.Compiler: Compiler;
    import dstep.Configuration: Configuration;
    import std.algorithm: map;
    import std.array: array;

    auto index = Index(false, false);
    Configuration config;
    Compiler compiler;
    const includeFlags = compiler.extraIncludePaths.map!(a => "-I" ~ a).array ~ "/usr/include";
    auto translationUnit = TranslationUnit.parse(index,
                                                 headerFileName,
                                                 includeFlags,
                                                 compiler.extraHeaders);

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
                    translate = !(severity == CXDiagnostic_Error || severity == CXDiagnostic_Fatal);

            message.put(diag.format);
            message.put("\n");
        }

        enforce(translate, message.data);
    }


    enforceCompiled;

    return translationUnit;
}


private string getHeaderFileName(string line) @safe pure {
    import std.algorithm: startsWith, countUntil;
    import std.range: dropBack;
    import std.array: popFront;
    import std.string: stripLeft;

    line = line.stripLeft;
    if(!line.startsWith(`#include `)) return "";

    const openingQuote = line.countUntil!(a => a == '"' || a == '<');
    const closingQuote = line[openingQuote + 1 .. $].countUntil!(a => a == '"' || a == '>') + openingQuote + 1;
    return line[openingQuote + 1 .. closingQuote];
}

@("getHeaderFileName")
@safe pure unittest {
    getHeaderFileName(`#include "foo.h"`).shouldEqual(`foo.h`);
    getHeaderFileName(`#include "bar.h"`).shouldEqual(`bar.h`);
    getHeaderFileName(`#include "foo.h" // comment`).shouldEqual(`foo.h`);
    getHeaderFileName(`#include <foo.h>`).shouldEqual(`foo.h`);
    getHeaderFileName(`    #include "foo.h"`).shouldEqual(`foo.h`);
}
