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
    import contract.aggregates: structOneFieldInt;
    import contract: TestMode, MockCursor;

    MockCursor tu;
    structOneFieldInt!(TestMode.mock)(tu);

    const actual = tu.child(0).toNode;
    const expected = Node(
        Struct(
            "Foo",
            [
                Node(Field(Type(Int()), "i")),
            ]
        )
    );

    () @trusted { actual.should == expected; }();
}


@("struct.onefield.double")
@safe unittest {
    auto doubleField = Cursor(Cursor.Kind.FieldDecl, "d");
    doubleField.type = ClangType(ClangType.Kind.Double, "double");
    auto struct_ = Cursor(Cursor.Kind.StructDecl, "Bar");
    struct_.children = [doubleField];

    () @trusted {
        struct_.toNode.should ==
            Node(
                Struct(
                    "Bar",
                    [
                        Node(Field(Type(Double()), "d")),
                    ]
                )
            );
    }();
}


@("struct.twofields")
@safe unittest {
    auto intField = Cursor(Cursor.Kind.FieldDecl, "i");
    intField.type = ClangType(ClangType.Kind.Int, "int");

    auto doubleField = Cursor(Cursor.Kind.FieldDecl, "d");
    doubleField.type = ClangType(ClangType.Kind.Double, "double");

    auto struct_ = Cursor(Cursor.Kind.StructDecl, "Baz");
    struct_.children = [intField, doubleField];

    () @trusted {
        struct_.toNode.should ==
            Node(
                Struct(
                    "Baz",
                    [
                        Node(Field(Type(Int()), "i")),
                        Node(Field(Type(Double()), "d")),
                    ]
                )
            );
    }();
}


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

    () @trusted {
        outer.toNode.should ==
            Node(
                Struct(
                    "Outer",
                    [
                        Node(Struct("Inner", [ Node(Field(Type(Int()), "x")) ])),
                        Node(Field(Type(UserDefinedType("Inner")), "inner")),
                    ],
                )
            );
    }();
}


@("struct.typedef.name")
@safe unittest {
    auto intField = Cursor(Cursor.Kind.FieldDecl, "i");
    intField.type = ClangType(ClangType.Kind.Int, "int");

    auto struct_ = Cursor(Cursor.Kind.StructDecl, "Struct_");
    struct_.type = ClangType(ClangType.Kind.Record, "Struct_");
    struct_.children = [intField];

    auto typedef_ = Cursor(Cursor.Kind.TypedefDecl, "Struct");
    typedef_.type = ClangType(ClangType.Kind.Typedef, "Struct");
    typedef_.underlyingType = ClangType(ClangType.Kind.Elaborated, "struct Struct_");
    typedef_.children = [struct_];

    () @trusted {
        typedef_.toNode.should == Node(Typedef("Struct", "Struct_"));
    }();
}
