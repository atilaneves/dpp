module contract.typedef_;


import contract;


@("typedef to a template type parameter")
@safe unittest {

    const tu = parse(
        Cpp(
            q{
                template <typename T>
                struct Struct {
                    typedef T Type;
                };
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const struct_ = tu.children[0];
    printChildren(struct_);

    struct_.kind.should == Cursor.Kind.ClassTemplate;
    struct_.children.length.should == 2;

    const typeParam = struct_.children[0];
    typeParam.kind.should == Cursor.Kind.TemplateTypeParameter;

    const typedef_ = struct_.children[1];
    typedef_.kind.should == Cursor.Kind.TypedefDecl;

    const underlyingType = typedef_.underlyingType;
    underlyingType.kind.should == Type.Kind.Unexposed;
    underlyingType.spelling.should == "T";

    const canonicalUnderlyingType = underlyingType.canonical;
    canonicalUnderlyingType.kind.should == Type.Kind.Unexposed;
    canonicalUnderlyingType.spelling.should == "type-parameter-0-0";
}
