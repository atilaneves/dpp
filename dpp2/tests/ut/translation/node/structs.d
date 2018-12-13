module ut.translation.node.structs;


import ut.translation.node;
import std.array: join;


@("onefield.int")
@safe pure unittest {
    enum node = Node(
        Struct(
            "Foo",
            [
                Node(Field(Type(Int()), "i")),
            ]
        )
    );

    enum translation = translate(node);
    writelnUt(translation);
    mixin(`static ` ~ translation.join("\n"));

    static assert(Foo.tupleof.length == 1);
    static assert(is(typeof(Foo.i) == int));
}


@("onefield.double")
@safe pure unittest {
    enum node = Node(
        Struct(
            "Bar",
            [
                Node(Field(Type(Double()), "d")),
            ]
        )
    );

    enum translation = translate(node);
    writelnUt(translation);
    mixin(`static ` ~ translation.join("\n"));

    static assert(Bar.tupleof.length == 1);
    static assert(is(typeof(Bar.d) == double));
}


@("twofields")
@safe pure unittest {
    enum node = Node(
        Struct(
            "Baz",
            [
                Node(Field(Type(Int()), "i",)),
                Node(Field(Type(Double()), "d",)),
            ]
        )
    );

    enum translation = translate(node);
    writelnUt(translation);
    mixin(`static ` ~ translation.join("\n"));

    static assert(Baz.tupleof.length == 2);
    static assert(is(typeof(Baz.i) == int));
    static assert(is(typeof(Baz.d) == double));
}


@("typedef.name")
@safe pure unittest {
    enum nodes = [
        Node(Struct("TypeDefd_", [])),
        Node(Typedef("TypeDefd", Type(UserDefinedType("TypeDefd_")))),
    ];
    enum translation = translate(nodes);
    writelnUt(translation);
    mixin(translation.join("\n"));

    static assert(is(TypeDefd));
    static assert(is(TypeDefd_));
}


@("typedef.anon")
@safe pure unittest {
    enum nodes = [
        Node(
            Struct(
                "",
                [
                    Node(Field(Type(Int()), "x")),
                    Node(Field(Type(Int()), "y")),
                    Node(Field(Type(Int()), "z")),
                ],
                "Nameless1", // type spelling
            ),
        ),
        Node(Typedef("Nameless1", Type(UserDefinedType("Nameless1")))),
        Node(
            Struct(
                "",
                [
                    Node(Field(Type(Double()), "d")),
                ],
                "Nameless2",  // type spelling
            ),
        ),
        Node(Typedef("Nameless2", Type(UserDefinedType("Nameless2")))),
    ];

    enum translation = "\n" ~ translate(nodes).join("\n");
    writelnUt(translation);
    mixin(translation);

    static assert(is(Nameless1), translation);
    static assert(is(typeof(Nameless1.x) == int), translation);
    static assert(is(typeof(Nameless1.y) == int), translation);
    static assert(is(typeof(Nameless1.z) == int), translation);

    static assert(is(Nameless2), translation);
    static assert(is(typeof(Nameless2.d) == double), translation);
}
