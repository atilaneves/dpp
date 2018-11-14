/**
   From clang.Cursor to dpp.node.Node.
   The tests can't be pure because clang.Cursor.children isn't.
 */
module ut.transform.cursor;


import ut.transform;
import clang: Cursor;
static import clang;
import dpp2.transform: toNode;



@("struct.onefield.int")
@safe unittest {
    auto intField = Cursor(Cursor.Kind.FieldDecl, "i");
    intField.type = clang.Type(clang.Type.Kind.Int, "int");
    auto struct_ = Cursor(Cursor.Kind.StructDecl, "Foo");
    struct_.children = [intField];

    struct_.toNode.should ==
        Node(
            Struct(
                "Foo",
                [
                    Field(
                        Type(Int()),
                        "i",
                    ),
                ]
            )
        );
}


@("struct.onefield.double")
@safe unittest {
    auto doubleField = Cursor(Cursor.Kind.FieldDecl, "d");
    doubleField.type = clang.Type(clang.Type.Kind.Double, "double");
    auto struct_ = Cursor(Cursor.Kind.StructDecl, "Bar");
    struct_.children = [doubleField];

    struct_.toNode.should ==
        Node(
            Struct(
                "Bar",
                [
                    Field(
                        Type(Double()),
                        "d",
                    ),
                ]
            )
        );
}


@("struct.twofields")
@safe unittest {
    auto intField = Cursor(Cursor.Kind.FieldDecl, "i");
    intField.type = clang.Type(clang.Type.Kind.Int, "int");

    auto doubleField = Cursor(Cursor.Kind.FieldDecl, "d");
    doubleField.type = clang.Type(clang.Type.Kind.Double, "double");

    auto struct_ = Cursor(Cursor.Kind.StructDecl, "Baz");
    struct_.children = [intField, doubleField];

    struct_.toNode.should ==
        Node(
            Struct(
                "Baz",
                [
                    Field(
                        Type(Int()),
                        "i",
                    ),
                    Field(
                        Type(Double()),
                        "d",
                    ),
                ]
            )
        );
}
