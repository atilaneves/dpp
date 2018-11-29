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
    const tu = mockTU!(Module("contract.aggregates"),
                       CodeURL("it.c.compile.struct_", "typedef.name"));
    const actual = tu.child(1).toNode;
    const expected = Node(Typedef("TypeDefd", "TypeDefd_"));

    () @trusted { actual.should == expected; }();
}
