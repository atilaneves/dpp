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
    const tu = mockTU!(Module("contract.aggregates"),
                       CodeURL("it.c.compile.struct_", "onefield.int"));

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


@("struct.nested")
@safe unittest {
    const tu = mockTU!(Module("contract.aggregates"),
                       CodeURL("it.c.compile.struct_", "nested"));

    const actual = tu.child(0).toNode;
    const expected = Node(
        Struct(
            "Outer",
            [
                Node(Field(Type(Int()), "integer")),
                Node(Struct("Inner", [ Node(Field(Type(Int()), "x")) ])),
                Node(Field(Type(UserDefinedType("Inner")), "inner")),
            ],
        )
   );


    () @trusted { actual.should == expected; }();
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
