module contract.constexpr;


import contract;


@("static constexpr variable in struct")
@safe unittest {

    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                struct Struct {
                    static constexpr int constExprValue = 42;
                    static const int constValue = 33;
                    static int value;
                };
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const struct_ = tu.children[0];
    printChildren(struct_);

    struct_.kind.shouldEqual(Cursor.Kind.StructDecl);
    struct_.children.length.shouldEqual(3);

    const constexprVar = struct_.children[0]; printChildren(constexprVar);
    const constVar     = struct_.children[1]; printChildren(constVar);
    const var          = struct_.children[2]; printChildren(var);

    constexprVar.kind.shouldEqual(Cursor.Kind.VarDecl);
    constexprVar.type.kind.shouldEqual(Type.Kind.Int);
    constexprVar.type.spelling.shouldEqual("const int");
    constexprVar.type.isConstQualified.shouldBeTrue;
    Token(Token.Kind.Keyword, "constexpr").should.be in constexprVar.tokens;
    constexprVar.tokens[$-1].spelling.should == "42";

    constVar.kind.shouldEqual(Cursor.Kind.VarDecl);
    constVar.type.kind.shouldEqual(Type.Kind.Int);
    constVar.type.spelling.shouldEqual("const int");
    constVar.type.isConstQualified.shouldBeTrue;
    Token(Token.Kind.Keyword, "constexpr").should.not.be in constVar.tokens;
    constVar.tokens[$-1].spelling.should == "33";

    var.kind.shouldEqual(Cursor.Kind.VarDecl);
    var.type.kind.shouldEqual(Type.Kind.Int);
    var.type.spelling.shouldEqual("int");
    var.type.isConstQualified.shouldBeFalse;
    Token(Token.Kind.Keyword, "constexpr").should.not.be in var.tokens;

}
