/**
   From clang.Cursor to dpp.node.Node.
   The tests can't be pure because clang.Cursor.children isn't.
 */
module ut.transform.cursor;


import ut.transform;
import clang: Cursor, ClangType = Type;
import dpp2.transform: toNode;



@("struct.onefield.int")
@safe unittest {
    auto intField = Cursor(Cursor.Kind.FieldDecl, "i");
    intField.type = ClangType(ClangType.Kind.Int, "int");
    auto struct_ = Cursor(Cursor.Kind.StructDecl, "Foo");
    struct_.children = [intField];

    struct_.toNode.should ==
        Node(
            Struct(
                "Foo",
                [
                    Field(Type(Int()), "i"),
                ]
            )
        );
}


@("struct.onefield.double")
@safe unittest {
    auto doubleField = Cursor(Cursor.Kind.FieldDecl, "d");
    doubleField.type = ClangType(ClangType.Kind.Double, "double");
    auto struct_ = Cursor(Cursor.Kind.StructDecl, "Bar");
    struct_.children = [doubleField];

    struct_.toNode.should ==
        Node(
            Struct(
                "Bar",
                [
                    Field(Type(Double()), "d"),
                ]
            )
        );
}


@("struct.twofields")
@safe unittest {
    auto intField = Cursor(Cursor.Kind.FieldDecl, "i");
    intField.type = ClangType(ClangType.Kind.Int, "int");

    auto doubleField = Cursor(Cursor.Kind.FieldDecl, "d");
    doubleField.type = ClangType(ClangType.Kind.Double, "double");

    auto struct_ = Cursor(Cursor.Kind.StructDecl, "Baz");
    struct_.children = [intField, doubleField];

    struct_.toNode.should ==
        Node(
            Struct(
                "Baz",
                [
                    Field(Type(Int()), "i"),
                    Field(Type(Double()), "d"),
                ]
            )
        );
}


// FIXME - `Field` should be an option for `Node`
@ShouldFail("Equal but not equal")
@("struct.nested")
@safe unittest {
    auto xfield = Cursor(Cursor.Kind.FieldDecl, "x");
    xfield.type = ClangType(ClangType.Kind.Int, "int");

    auto innerStruct = Cursor(Cursor.Kind.StructDecl, "Inner");
    innerStruct.type = ClangType(ClangType.Kind.Record, "Outer::Inner");
    innerStruct.children = [xfield];

    auto innerField = Cursor(Cursor.Kind.FieldDecl, "inner");
    innerField.type = ClangType(ClangType.Kind.Elaborated, "struct Inner");
    innerField.children = [innerStruct];

    auto outer = Cursor(Cursor.Kind.StructDecl, "Outer");
    outer.type = ClangType(ClangType.Kind.Record, "Outer");
    outer.children = [innerStruct, innerField];

    outer.toNode.should ==
        Node(
            Struct(
                "Outer",
                [
                    Field(Type(UserDefinedType("Inner")), "inner"),
                ],
                [
                    Struct("Inner", [ Field(Type(Int()), "x") ]),
                ],
            )
        );
}
