module contract.constexpr;


import contract;
import clang: Token;


@("variable.struct.static")
@safe unittest {

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
    constexprVar.kind.shouldEqual(Cursor.Kind.VarDecl);
    constexprVar.type.kind.shouldEqual(Type.Kind.Int);
    constexprVar.type.spelling.shouldEqual("const int");
    constexprVar.type.isConstQualified.shouldBeTrue;
    Token(Token.Kind.Keyword, "constexpr").should.be in constexprVar.tokens;
    constexprVar.tokens[$-1].spelling.should == "42";
    constexprVar.children.length.should == 1;

    const constExprIntLit = constexprVar.child(0);
    constExprIntLit.shouldMatch(Cursor.Kind.IntegerLiteral, "");
    constExprIntLit.type.shouldMatch(Type.Kind.Int, "int");
    constExprIntLit.tokens.should == [Token(Token.Kind.Literal, "42")];

    const constVar = struct_.children[1]; printChildren(constVar);
    constVar.kind.shouldEqual(Cursor.Kind.VarDecl);
    constVar.type.kind.shouldEqual(Type.Kind.Int);
    constVar.type.spelling.shouldEqual("const int");
    constVar.type.isConstQualified.shouldBeTrue;
    Token(Token.Kind.Keyword, "constexpr").should.not.be in constVar.tokens;
    constVar.tokens[$-1].spelling.should == "33";
    constVar.children.length.should == 1;

    const constIntLit = constVar.child(0);
    constIntLit.shouldMatch(Cursor.Kind.IntegerLiteral, "");
    constIntLit.type.shouldMatch(Type.Kind.Int, "int");
    constIntLit.tokens.should == [Token(Token.Kind.Literal, "33")];

    const var = struct_.children[2]; printChildren(var);
    var.kind.shouldEqual(Cursor.Kind.VarDecl);
    var.type.kind.shouldEqual(Type.Kind.Int);
    var.type.spelling.shouldEqual("int");
    var.type.isConstQualified.shouldBeFalse;
    Token(Token.Kind.Keyword, "constexpr").should.not.be in var.tokens;
    var.children.length.should == 0;
}


@("variable.init.braces")
@safe unittest {

    const tu = parse(
        Cpp(
            q{
                constexpr int var{};
            }
        )
    );

    tu.children.length.should == 1;
    const var = tu.child(0);

    var.shouldMatch(Cursor.Kind.VarDecl, "var");
    var.type.shouldMatch(Type.Kind.Int, "const int");
    printChildren(var);
    var.children.length.should == 1;

    const initList = var.child(0);
    initList.shouldMatch(Cursor.Kind.InitListExpr, "");
    initList.type.shouldMatch(Type.Kind.Int, "int");
    initList.tokens.should == [
        Token(Token.Kind.Punctuation, "{"),
        Token(Token.Kind.Punctuation, "}")
    ];
    initList.children.length.should == 0;
}
