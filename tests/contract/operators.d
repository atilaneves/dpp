module contract.operators;


import contract;


@("opCast no template")
@safe unittest {

    const tu = parse(
        Cpp(
            q{
                struct Struct {
                    operator int() const;
                };
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const struct_ = tu.children[0];
    printChildren(struct_);
    struct_.kind.should == Cursor.Kind.StructDecl;
    struct_.children.length.shouldEqual(1);

    const conversion = struct_.children[0];
    printChildren(conversion);

    conversion.kind.should == Cursor.Kind.ConversionFunction;
    conversion.spelling.should == "operator int";
}

@("opCast template")
@safe unittest {

    const tu = parse(
        Cpp(
            q{
                template<typename T>
                struct Struct {
                    operator T() const;
                };
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const struct_ = tu.children[0];
    printChildren(struct_);
    struct_.kind.should == Cursor.Kind.ClassTemplate;
    struct_.children.length.shouldEqual(2);

    const typeParam = struct_.children[0];
    typeParam.kind.should == Cursor.Kind.TemplateTypeParameter;

    const conversion = struct_.children[1];
    printChildren(conversion);

    conversion.kind.should == Cursor.Kind.ConversionFunction;
    conversion.spelling.should == "operator type-parameter-0-0";

    const retType = conversion.returnType;
    retType.kind.should == Type.Kind.Unexposed;
    retType.canonical.kind.should == Type.Kind.Unexposed;
    retType.spelling.should == "T";
    retType.canonical.spelling.should == "type-parameter-0-0";
}
