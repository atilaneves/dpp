module contract.namespace;


import contract;



@Tags("contract")
@("struct")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                namespace ns {
                    struct Struct {

                    };
                }
            }
        )
    );

    tu.children.length.should == 1;
    const namespace = tu.children[0];
    namespace.kind.should == Cursor.Kind.Namespace;

    namespace.children.length.should == 1;
    const struct_ = namespace.children[0];
    struct_.kind.should == Cursor.Kind.StructDecl;

    struct_.spelling.should == "Struct";
    struct_.type.spelling.should == "ns::Struct";
}
