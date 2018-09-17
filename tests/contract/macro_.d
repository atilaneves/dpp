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
