module contract.array;

import contract;

@("int[4]")
unittest {
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
