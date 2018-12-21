module contract.array;


import contract;


@Tags("contract")
@("int[4]")
@safe unittest {
    const tu = parse(
        C(
            q{
                int arr[4];
            }
        )
    );

    tu.children.length.should == 1;
    const cursor = tu.children[0];

    cursor.kind.should == Cursor.Kind.VarDecl;
    cursor.spelling.should == "arr";

    const type = cursor.type;
    type.kind.should == Type.Kind.ConstantArray;
    type.spelling.should == "int [4]";
    type.canonical.kind.should == Type.Kind.ConstantArray;
    type.canonical.spelling.should == "int [4]";
}


@Tags("contract")
@("flexible")
@safe unittest {
    const tu = parse(
        C(
            q{
                struct Slice {
                    int length;
                    unsigned char arr[];
                };
            }
        )
    );

    tu.children.length.should == 1;
    const cursor = tu.children[0];
    const structChildren = cursor.children;
    structChildren.length.should == 2;

    structChildren[0].kind.should == Cursor.Kind.FieldDecl;
    structChildren[0].spelling.should == "length";
    structChildren[0].type.kind.should == Type.Kind.Int;
    structChildren[0].type.spelling.should == "int";
    structChildren[0].type.canonical.kind.should == Type.Kind.Int;
    structChildren[0].type.canonical.spelling.should == "int";

    structChildren[1].kind.should == Cursor.Kind.FieldDecl;
    structChildren[1].spelling.should == "arr";
    structChildren[1].type.kind.should == Type.Kind.IncompleteArray;
    structChildren[1].type.spelling.should == "unsigned char []";
    structChildren[1].type.canonical.kind.should == Type.Kind.IncompleteArray;
    structChildren[1].type.canonical.spelling.should == "unsigned char []";
}
