module contract.aggregates;


import contract;


@("struct.onefield.int.manual")
@MockTU!(
    {
        import clang;
        return MockCursor(
            Cursor.Kind.TranslationUnit,
            "",
            MockType(),
            [
                MockCursor(Cursor.Kind.StructDecl,
                           "Foo",
                           MockType(Type.Kind.Record,
                                    "struct Foo"),
                           [
                               MockCursor(Cursor.Kind.FieldDecl,
                                          "i",
                                          MockType(Type.Kind.Int,
                                                   "int")),
                           ],
                    ),
            ],
        );
    }
)
@Types!(Cursor, MockCursor)
void testStructOneFieldInt(T)() {

    mixin createTU!(T, "it.c.compile.struct_", "onefield.int");

    tu.children.length.should == 1;

    const struct_ = tu.children[0];
    struct_.kind.should == Cursor.Kind.StructDecl;
    struct_.spelling.should == "Foo";
    struct_.type.kind.should == Type.Kind.Record;
    struct_.type.spelling.should == "struct Foo";

    printChildren(struct_);
    struct_.children.length.should == 1;
    const member = struct_.children[0];
    member.kind.should == Cursor.Kind.FieldDecl;
    member.spelling.should == "i";

    member.type.kind.should == Type.Kind.Int;
    member.type.spelling.should == "int";
}


mixin Contract!(
    TestName("struct.onefield.int.auto"),
    CodeURL("it.c.compile.struct_", "onefield.int"),
    q{
        tu.children.expectLengthEqual!mode(1);

        auto struct_ = tu.child(0);
        struct_.kind.expect!mode == Cursor.Kind.StructDecl;
        struct_.spelling.expect!mode == "Foo";
        struct_.type.kind.expect!mode == Type.Kind.Record;
        struct_.type.spelling.expect!mode == "struct Foo";

        printChildren(struct_);
        struct_.children.expectLengthEqual!mode(1);

        auto member = struct_.child(0);

        member.kind.expect!mode == Cursor.Kind.FieldDecl;
        member.spelling.expect!mode == "i";

        member.type.kind.expect!mode == Type.Kind.Int;
        member.type.spelling.expect!mode == "int";
    }
);


mixin Contract!(
    TestName("struct.nested.c"),
    CodeURL("it.c.compile.struct_", "nested"),
    q{
        tu.children.expectLengthEqual!mode(1);

        auto outer = tu.child(0);
        outer.kind.expect!mode == Cursor.Kind.StructDecl;
        outer.spelling.expect!mode == "Outer";
        outer.type.kind.expect!mode == Type.Kind.Record;
        outer.type.spelling.expect!mode == "struct Outer";

        printChildren(outer);
        outer.children.expectLengthEqual!mode(3);


        auto integer = outer.child(0);
        integer.kind.expect!mode == Cursor.Kind.FieldDecl;
        integer.spelling.expect!mode == "integer";
        integer.type.kind.expect!mode == Type.Kind.Int;
        integer.type.spelling.expect!mode == "int";


        auto innerStruct = outer.child(1);
        innerStruct.kind.expect!mode == Cursor.Kind.StructDecl;
        innerStruct.spelling.expect!mode == "Inner";
        innerStruct.type.kind.expect!mode == Type.Kind.Record;
        innerStruct.type.spelling.expect!mode == "struct Inner";
        innerStruct.type.canonical.kind.expect!mode == Type.Kind.Record;
        innerStruct.type.canonical.spelling.expect!mode == "struct Inner";

        printChildren(innerStruct);
        innerStruct.children.expectLengthEqual!mode(1);  // the `x` field

        auto xfield = innerStruct.child(0);
        xfield.kind.expect!mode == Cursor.Kind.FieldDecl;
        xfield.spelling.expect!mode == "x";
        xfield.type.kind.expect!mode == Type.Kind.Int;


        auto innerField = outer.child(2);
        innerField.kind.expect!mode == Cursor.Kind.FieldDecl;
        innerField.spelling.expect!mode == "inner";
        printChildren(innerField);
        innerField.children.expectLengthEqual!mode(1);  // the Inner StructDecl

        innerField.type.kind.expect!mode == Type.Kind.Elaborated;
        innerField.type.spelling.expect!mode == "struct Inner";
        innerField.type.canonical.kind.expect!mode == Type.Kind.Record;
        innerField.type.canonical.spelling.expect!mode == "struct Inner";

        auto innerFieldChild = innerField.child(0);
        innerFieldChild.expect!mode == innerStruct;
    }
);


// Slightly different from the C version
@Tags("cpp")
@("struct.nested.cpp")
@safe unittest {

    const tu = parse(
        Cpp(
            q{
                struct Outer {
                    int integer;
                    struct Inner {
                        int x;
                    } inner;
                };
            }
        )
    );

    const outer = tu.children[0];
    printChildren(outer);
    outer.children.length.should == 3;


    const integer = outer.children[0];
    integer.kind.should == Cursor.Kind.FieldDecl;
    integer.spelling.should == "integer";
    integer.type.kind.should == Type.Kind.Int;
    integer.type.spelling.should == "int";


    const innerStruct = outer.children[1];
    innerStruct.kind.should == Cursor.Kind.StructDecl;
    innerStruct.spelling.should == "Inner";
    printChildren(innerStruct);
    innerStruct.children.length.should == 1;  // the `x` field

    innerStruct.type.kind.should == Type.Kind.Record;
    innerStruct.type.spelling.should == "Outer::Inner";
    innerStruct.type.canonical.kind.should == Type.Kind.Record;
    innerStruct.type.canonical.spelling.should == "Outer::Inner";

    const xfield = innerStruct.children[0];
    xfield.kind.should == Cursor.Kind.FieldDecl;
    xfield.spelling.should == "x";
    xfield.type.kind.should == Type.Kind.Int;


    const innerField = outer.children[2];
    innerField.kind.should == Cursor.Kind.FieldDecl;
    innerField.spelling.should == "inner";
    printChildren(innerField);
    innerField.children.length.should == 1;  // the Inner StructDecl

    innerField.type.kind.should == Type.Kind.Elaborated;
    innerField.type.spelling.should == "struct Inner";
    innerField.type.canonical.kind.should == Type.Kind.Record;
    innerField.type.canonical.spelling.should == "Outer::Inner";

    innerField.children[0].should == innerStruct;
}

mixin Contract!(
    TestName("struct.typedef.name"),
    CodeURL("it.c.compile.struct_", "typedef.name"),
    q{
        tu.children.expectLengthEqual!mode(2);

        auto struct_ = tu.child(0);
        struct_.kind.expect!mode == Cursor.Kind.StructDecl;
        struct_.spelling.expect!mode == "TypeDefd_";
        struct_.type.kind.expect!mode == Type.Kind.Record;
        struct_.type.spelling.expect!mode == "struct TypeDefd_";

        auto typedef_ = tu.child(1);
        typedef_.kind.expect!mode == Cursor.Kind.TypedefDecl;
        typedef_.spelling.expect!mode == "TypeDefd";
        typedef_.type.kind.expect!mode == Type.Kind.Typedef;
        typedef_.type.spelling.expect!mode == "TypeDefd";

        typedef_.underlyingType.kind.expect!mode == Type.Kind.Elaborated;
        typedef_.underlyingType.spelling.expect!mode == "struct TypeDefd_";
        typedef_.underlyingType.canonical.kind.expect!mode == Type.Kind.Record;
        typedef_.underlyingType.canonical.spelling.expect!mode == "struct TypeDefd_";

        printChildren(typedef_);
        typedef_.children.expectLengthEqual!mode(1);
        typedef_.children[0].expect!mode == struct_;
    }
);


@Tags("cpp")
@("struct.typedef.name.cpp")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                typedef struct TypeDefd_ {
                    int i;
                    double d;
                } TypeDefd;
            }
        )
    );

    tu.children.length.should == 2;

    const struct_ = tu.children[0];
    struct_.kind.should == Cursor.Kind.StructDecl;
    struct_.spelling.should == "TypeDefd_";
    struct_.type.kind.should == Type.Kind.Record;
    struct_.type.spelling.should == "TypeDefd_";

    const typedef_ = tu.children[1];
    typedef_.kind.should == Cursor.Kind.TypedefDecl;
    typedef_.spelling.should == "TypeDefd";
    typedef_.type.kind.should == Type.Kind.Typedef;
    typedef_.type.spelling.should == "TypeDefd";

    typedef_.underlyingType.kind.should == Type.Kind.Elaborated;
    typedef_.underlyingType.spelling.should == "struct TypeDefd_";
    typedef_.underlyingType.canonical.kind.should == Type.Kind.Record;
    typedef_.underlyingType.canonical.spelling.should == "TypeDefd_";

    printChildren(typedef_);
    typedef_.children.length.should == 1;
    typedef_.children[0].should == struct_;
}


mixin Contract!(
    TestName("struct.typedef.anon"),
    CodeURL("it.c.compile.struct_", "typedef.anon"),
    q{
        tu.children.expectLengthEqual!mode(4);

        auto struct1 = tu.child(0);
        struct1.kind.expect!mode == Cursor.Kind.StructDecl;
        struct1.spelling.expect!mode == "";
        struct1.type.kind.expect!mode == Type.Kind.Record;
        // the cursor has no spelling but the type does
        struct1.type.spelling.expect!mode == "Nameless1";

        struct1.children.expectLengthEqual!mode(3);
        struct1.child(0).kind.expect!mode == Cursor.Kind.FieldDecl;
        struct1.child(0).spelling.expect!mode == "x";
        struct1.child(0).type.kind.expect!mode == Type.Kind.Int;
        struct1.child(1).kind.expect!mode == Cursor.Kind.FieldDecl;
        struct1.child(1).spelling.expect!mode == "y";
        struct1.child(1).type.kind.expect!mode == Type.Kind.Int;
        struct1.child(2).kind.expect!mode == Cursor.Kind.FieldDecl;
        struct1.child(2).spelling.expect!mode == "z";
        struct1.child(2).type.kind.expect!mode == Type.Kind.Int;

        auto typedef1 = tu.child(1);
        typedef1.kind.expect!mode == Cursor.Kind.TypedefDecl;
        typedef1.spelling.expect!mode == "Nameless1";
        typedef1.type.kind.expect!mode == Type.Kind.Typedef;
        typedef1.type.spelling.expect!mode == "Nameless1";

        typedef1.underlyingType.kind.expect!mode == Type.Kind.Elaborated;
        typedef1.underlyingType.spelling.expect!mode == "struct Nameless1";
        typedef1.underlyingType.canonical.kind.expect!mode == Type.Kind.Record;
        typedef1.underlyingType.canonical.spelling.expect!mode == "Nameless1";

        printChildren(typedef1);
        typedef1.children.expectLengthEqual!mode(1);
        typedef1.children[0].expect!mode == struct1;

        auto struct2 = tu.child(2);
        struct2.kind.expect!mode == Cursor.Kind.StructDecl;
        struct2.spelling.expect!mode == "";
        struct2.type.kind.expect!mode == Type.Kind.Record;
        struct2.type.spelling.expect!mode == "Nameless2";

        struct2.children.expectLengthEqual!mode(1);
        struct2.child(0).kind.expect!mode == Cursor.Kind.FieldDecl;
        struct2.child(0).spelling.expect!mode == "d";
        struct2.child(0).type.kind.expect!mode == Type.Kind.Double;

        auto typedef2 = tu.child(3);
        typedef2.kind.expect!mode == Cursor.Kind.TypedefDecl;
        typedef2.spelling.expect!mode == "Nameless2";
        typedef2.type.kind.expect!mode == Type.Kind.Typedef;
        typedef2.type.spelling.expect!mode == "Nameless2";

        typedef2.underlyingType.kind.expect!mode == Type.Kind.Elaborated;
        typedef2.underlyingType.spelling.expect!mode == "struct Nameless2";
        typedef2.underlyingType.canonical.kind.expect!mode == Type.Kind.Record;
        typedef2.underlyingType.canonical.spelling.expect!mode == "Nameless2";

        printChildren(typedef2);
        typedef2.children.expectLengthEqual!mode(1);
        typedef2.children[0].expect!mode == struct2;
    }
);


@Tags("cpp")
@("struct.typedef.anon.cpp")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                typedef struct {
                    int i;
                    double d;
                } TypeDefd;
            }
        )
    );

    tu.children.length.should == 2;

    const struct_ = tu.children[0];
    struct_.kind.should == Cursor.Kind.StructDecl;
    struct_.spelling.should == "";
    struct_.type.kind.should == Type.Kind.Record;
    struct_.type.spelling.should == "TypeDefd";

    const typedef_ = tu.children[1];
    typedef_.kind.should == Cursor.Kind.TypedefDecl;
    typedef_.spelling.should == "TypeDefd";
    typedef_.type.kind.should == Type.Kind.Typedef;
    typedef_.type.spelling.should == "TypeDefd";

    typedef_.underlyingType.kind.should == Type.Kind.Elaborated;
    typedef_.underlyingType.spelling.should == "struct TypeDefd";
    typedef_.underlyingType.canonical.kind.should == Type.Kind.Record;
    typedef_.underlyingType.canonical.spelling.should == "TypeDefd";

    printChildren(typedef_);
    typedef_.children.length.should == 1;
    typedef_.children[0].should == struct_;
}


mixin Contract!(
    TestName("struct.typedef.before"),
    CodeURL("it.c.compile.struct_", "typedef.before"),
    q{
        tu.children.expectLengthEqual!mode(3);

        auto struct1 = tu.child(0);
        struct1.kind.expect!mode == Cursor.Kind.StructDecl;
        struct1.spelling.expect!mode == "A";
        struct1.type.kind.expect!mode == Type.Kind.Record;
        struct1.type.spelling.expect!mode == "struct A";

        // forward declaration has no children
        struct1.children.expectLengthEqual!mode(0);

        auto typedef_ = tu.child(1);
        typedef_.kind.expect!mode == Cursor.Kind.TypedefDecl;
        typedef_.spelling.expect!mode == "B";
        typedef_.type.kind.expect!mode == Type.Kind.Typedef;
        typedef_.type.spelling.expect!mode == "B";

        typedef_.underlyingType.kind.expect!mode == Type.Kind.Elaborated;
        typedef_.underlyingType.spelling.expect!mode == "struct A";
        typedef_.underlyingType.canonical.kind.expect!mode == Type.Kind.Record;
        typedef_.underlyingType.canonical.spelling.expect!mode == "struct A";

        auto struct2 = tu.child(2);
        struct2.kind.expect!mode == Cursor.Kind.StructDecl;
        struct2.spelling.expect!mode == "A";
        struct2.type.kind.expect!mode == Type.Kind.Record;
        struct2.type.spelling.expect!mode == "struct A";

        // definition has the child
        struct2.children.expectLengthEqual!mode(1);
        auto child = struct2.child(0);

        child.kind.expect!mode == Cursor.Kind.FieldDecl;
        child.spelling.expect!mode == "a";
        child.type.kind.expect!mode == Type.Kind.Int;
        child.type.spelling.expect!mode == "int";
    }
);
