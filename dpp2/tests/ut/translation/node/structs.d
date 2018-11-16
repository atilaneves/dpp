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
