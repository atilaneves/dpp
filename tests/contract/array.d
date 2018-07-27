module contract.array;

import contract;

@("int[4]")
@safe unittest {
    const tu = parse(
        C(
            q{
                int arr[4];
            }
        )
    );

    tu.children.length.shouldEqual(1);
    const cursor = tu.children[0];

    cursor.kind.shouldEqual(Cursor.Kind.VarDecl);
    cursor.spelling.shouldEqual("arr");

    const type = cursor.type;
    type.kind.shouldEqual(Type.Kind.ConstantArray);
    type.spelling.shouldEqual("int [4]");
    type.canonical.kind.shouldEqual(Type.Kind.ConstantArray);
    type.canonical.spelling.shouldEqual("int [4]");
}


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

    tu.children.length.shouldEqual(1);
    const cursor = tu.children[0];
    const structChildren = cursor.children;
    structChildren.length.shouldEqual(2);

    structChildren[0].kind.shouldEqual(Cursor.Kind.FieldDecl);
    structChildren[0].spelling.shouldEqual("length");
    structChildren[0].type.kind.shouldEqual(Type.Kind.Int);
    structChildren[0].type.spelling.shouldEqual("int");
    structChildren[0].type.canonical.kind.shouldEqual(Type.Kind.Int);
    structChildren[0].type.canonical.spelling.shouldEqual("int");

    structChildren[1].kind.shouldEqual(Cursor.Kind.FieldDecl);
    structChildren[1].spelling.shouldEqual("arr");
    structChildren[1].type.kind.shouldEqual(Type.Kind.IncompleteArray);
    structChildren[1].type.spelling.shouldEqual("unsigned char []");
    structChildren[1].type.canonical.kind.shouldEqual(Type.Kind.IncompleteArray);
    structChildren[1].type.canonical.spelling.shouldEqual("unsigned char []");
}
