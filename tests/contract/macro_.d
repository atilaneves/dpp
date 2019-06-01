module contract.macro_;


import contract;


@Tags("contract")
@("macro after enum")
@safe unittest {

    import clang: TranslationUnitFlags;
    import std.algorithm: countUntil;

    const tu = parse(
        C(
            `
                enum TheEnum { BAR = 42 };
                #define BAR 42
            `
        ),
        TranslationUnitFlags.DetailedPreprocessingRecord,
    );

    tu.children.length.shouldBeGreaterThan(2);

    const enumIndex = tu.children.countUntil!(a => a.kind == Cursor.Kind.EnumDecl && a.spelling == "TheEnum");
    const macroIndex = tu.children.countUntil!(a => a.kind == Cursor.Kind.MacroDefinition && a.spelling == "BAR");

    // for unfathomable reasons, clang puts all the macros at the top
    // completely disregarding the order they appear in the code
    enumIndex.shouldBeGreaterThan(macroIndex);
}


@Tags("contract")
@("tokens")
@safe unittest {
    import dpp.translation.macro_: isBuiltinMacro;
    import clang: TranslationUnitFlags, Token;
    import std.algorithm: filter;
    import std.array: array;

    const tu = parse(
        C(
            `
                #define INT 42
                #define DOUBLE 33.3
                #define OCTAL 00177
                #define STRING "foobar"
            `
        ),
        TranslationUnitFlags.DetailedPreprocessingRecord,
    );

    auto childrenRange = tu.children.filter!(a => !isBuiltinMacro(a));
    const children = () @trusted { return childrenRange.array; }();
    children.length.should == 4;

    const int_ = children[0];
    int_.tokens.should == [
        Token(Token.Kind.Identifier, "INT"),
        Token(Token.Kind.Literal, "42"),
    ];

    const double_ = children[1];
    double_.tokens.should == [
        Token(Token.Kind.Identifier, "DOUBLE"),
        Token(Token.Kind.Literal, "33.3"),
    ];

    const octal = children[2];
    octal.tokens.should == [
        Token(Token.Kind.Identifier, "OCTAL"),
        Token(Token.Kind.Literal, "00177"),
    ];

    const string_ = children[3];
    string_.tokens.should == [
        Token(Token.Kind.Identifier, "STRING"),
        Token(Token.Kind.Literal, `"foobar"`),
    ];
}
