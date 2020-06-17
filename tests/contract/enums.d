module contract.enums;


import contract;


@("legacy")
@safe unittest {

    import clang.c.index;

    const tu = parse(
        Cpp(
            q{
                enum Enum {
                    foo,
                    bar,
                    baz,
                };
            }
        )
    );

    tu.children.length.should == 1;
    const enum_ = tu.children[0];
    enum_.shouldMatch(Cursor.Kind.EnumDecl, "Enum");
    printChildren(enum_);
    enum_.children.length.should == 3;

    version(Windows)
        Type(clang_getEnumDeclIntegerType(enum_.cx)).shouldMatch(Type.Kind.Int, "int");
    else
        Type(clang_getEnumDeclIntegerType(enum_.cx)).shouldMatch(Type.Kind.UInt, "unsigned int");
}


@("class.type")
@safe unittest {

    import clang.c.index;

    const tu = parse(
        Cpp(
            q{
                enum class Enum: unsigned char {
                    foo,
                    bar,
                    baz,
                };
            }
        )
    );

    tu.children.length.should == 1;
    const enum_ = tu.children[0];
    enum_.shouldMatch(Cursor.Kind.EnumDecl, "Enum");
    printChildren(enum_);
    enum_.children.length.should == 3;

    Type(clang_getEnumDeclIntegerType(enum_.cx)).shouldMatch(Type.Kind.UChar, "unsigned char");
}
