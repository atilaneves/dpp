module include.clang;

import clang.c.Index: CXTranslationUnit_Flags;
import std.traits: ReturnType;


struct TranslationUnit {

    import clang.TranslationUnit: _TranslationUnit = TranslationUnit;

    _TranslationUnit _impl;
    Cursor[] cursors;

    this(_TranslationUnit _impl) @trusted {
        this._impl = _impl;

        foreach(cursor, _; _impl.cursor.all) {
            cursors ~= Cursor(cursor.spelling, cast(Cursor.Kind)cursor.kind);
        }
    }
}

struct Cursor {

    mixin(kindMixinStr);

    string spelling;
    Kind kind;
}


private string kindMixinStr() {
    if(!__ctfe) return "";

    import clang.c.Index: CXCursorKind;
    import std.string: join, replace;
    import std.traits: EnumMembers;
    import std.conv: to;
    import std.algorithm: canFind;

    string[] lines;

    lines ~= `import clang.c.Index: CXCursorKind;`;
    lines ~= "enum Kind {";

    foreach(member; EnumMembers!CXCursorKind) {
        auto memberId = member.to!string;
        auto newId = memberId.replace("CXCursor_", "");
        auto newLine = newId ~ ` = CXCursorKind.` ~ memberId ~ `,`;
        if(!lines.canFind(newLine))
            lines ~= newId ~ ` = CXCursorKind.` ~ memberId ~ `,`;
    }

    lines ~= "}";

    return lines.join("\n");
}


auto parse(in string fileName,
           in CXTranslationUnit_Flags options = CXTranslationUnit_Flags.CXTranslationUnit_DetailedPreprocessingRecord) @trusted {

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
                    translate = !(severity == CXDiagnostic_Error || severity == CXDiagnostic_Fatal);

            message.put(diag.format);
            message.put("\n");
        }

        enforce(translate, message.data);
    }


    enforceCompiled;

    return TranslationUnit(translationUnit);
}
