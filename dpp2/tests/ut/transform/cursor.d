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

    const actual = tu.toNode;
    const expected = [Node(
        Struct(
            "Foo",
            [
                Node(Field(Type(Int()), "i")),
            ],
            "struct Foo",
        )
    )];

    () @trusted { actual.should == expected; }();
}


@("struct.nested")
@safe unittest {
    const tu = mockTU!(Module("contract.aggregates"),
                       CodeURL("it.c.compile.struct_", "nested"));

    const actual = tu.toNode;
    const expected = [Node(
        Struct(
            "Outer",
            [
                Node(Field(Type(Int()), "integer")),
                Node(Struct("Inner", [ Node(Field(Type(Int()), "x")) ], "struct Inner")),
                Node(Field(Type(UserDefinedType("Inner")), "inner")),
            ],
            "struct Outer",
        )
    )];

    () @trusted { actual.should == expected; }();
}


@("struct.typedef.name")
@safe unittest {
    const tu = mockTU!(Module("contract.aggregates"),
                       CodeURL("it.c.compile.struct_", "typedef.name"));

    const actual = tu.toNode;
    const expected = [
        Node(Struct("TypeDefd_", [], "struct TypeDefd_")),
        Node(Typedef("TypeDefd", Type(UserDefinedType("TypeDefd_")))),
    ];

    () @trusted { actual.should == expected; }();
}


@("struct.typedef.anon")
@safe unittest {
    const tu = mockTU!(Module("contract.aggregates"),
                       CodeURL("it.c.compile.struct_", "typedef.anon"));

    const actual = tu.toNode;
    const expected = [
        Node(
            Struct(
                "",
                [
                    Node(Field(Type(Int()), "x")),
                    Node(Field(Type(Int()), "y")),
                    Node(Field(Type(Int()), "z")),
                ],
                "Nameless1",
            ),
        ),
        Node(Typedef("Nameless1", Type(UserDefinedType("Nameless1")))),
        Node(
            Struct(
                "",
                [
                    Node(Field(Type(Double()), "d")),
                ],
                "Nameless2",
            ),
        ),
        Node(Typedef("Nameless2", Type(UserDefinedType("Nameless2")))),
    ];


    () @trusted { actual.should == expected; }();
}


@("struct.typedef.before")
@safe unittest {
    const tu = mockTU!(Module("contract.aggregates"),
                       CodeURL("it.c.compile.struct_", "typedef.before"));
    const actual = tu.toNode;
    const expected = [
        Node(Typedef("B", Type(UserDefinedType("A")))),
        Node(Struct("A", [Node(Field(Type(Int()), "a"))], "struct A")),
    ];

    () @trusted { actual.should == expected; }();
}
