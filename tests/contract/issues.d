module contract.issues;


import contract;



@Tags("contract")
@("119")
@safe unittest {

    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                enum class Enum { foo, bar, baz };
            }
        )
    );

    tu.children.length.should == 1;
    const enum_ = tu.child(0);

    enum_.shouldMatch(Cursor.Kind.EnumDecl, "Enum");
    enum_.type.shouldMatch(Type.Kind.Enum, "Enum");
    printChildren(enum_);
    enum_.children.length.should == 3; // EnumConstantDecl

    Token(Token.Kind.Keyword, "class").should.be in enum_.tokens;
}



@Tags("contract")
@("126")
@safe unittest {

    import clang.c.index;

    const tu = parse(
        Cpp(
            q{
                template <typename T>
                struct Foo {
                    T ts[42];
                };
            }
        )
    );

    tu.children.length.should == 1;

    const foo = tu.child(0);
    foo.shouldMatch(Cursor.Kind.ClassTemplate, "Foo");
    foo.type.shouldMatch(Type.Kind.Invalid, "");
    printChildren(foo);
    foo.children.length.should == 2;

    const typeParam = foo.child(0);
    typeParam.shouldMatch(Cursor.Kind.TemplateTypeParameter, "T");
    typeParam.type.shouldMatch(Type.Kind.Unexposed, "T");
    printChildren(typeParam);
    typeParam.children.length.should == 0;

    const fieldDecl = foo.child(1);
    fieldDecl.shouldMatch(Cursor.Kind.FieldDecl, "ts");
    try
        fieldDecl.type.shouldMatch(Type.Kind.ConstantArray, "T [42]");
    catch(Exception _)
        fieldDecl.type.shouldMatch(Type.Kind.ConstantArray, "T[42]");

    printChildren(fieldDecl);
    fieldDecl.children.length.should == 2;
    // This is why the issue was filed
    fieldDecl.type.getSizeof.should == -3;
    writelnUt(clang_getTemplateCursorKind(foo.cx));

    const typeRef = fieldDecl.child(0);
    typeRef.shouldMatch(Cursor.Kind.TypeRef, "T");
    typeRef.type.shouldMatch(Type.Kind.Unexposed, "T");
    printChildren(typeRef);
    typeRef.children.length.should == 0;

    const intLiteral = fieldDecl.child(1);
    intLiteral.shouldMatch(Cursor.Kind.IntegerLiteral, "");
    intLiteral.type.shouldMatch(Type.Kind.Int, "int");
    printChildren(intLiteral);
    intLiteral.children.length.should == 0;
}
