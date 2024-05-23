module contract.aggregates;


import contract;



// mixin Contract!(TestName("struct.onefield.int"), contract_onefield_int);
// @ContractFunction(CodeURL("it.c.compile.struct_", "onefield.int"))
auto contract_onefield_int(TestMode mode, CursorType)(auto ref CursorType tu) {

    tu.kind.expect == Cursor.Kind.TranslationUnit;
    tu.children.expectLength == 1;

    auto struct_ = tu.child(0);
    struct_.isDefinition.expect == true;
    struct_.expectEqual(Cursor.Kind.StructDecl, "Foo");
    struct_.type.expectEqual(Type.Kind.Record, "struct Foo");

    printChildren(struct_);
    struct_.children.expectLength == 1;

    auto member = struct_.child(0);
    member.expectEqual(Cursor.Kind.FieldDecl,"i");
    member.type.expectEqual(Type.Kind.Int, "int");

    static if(is(CursorType == MockCursor)) return tu;
}



// mixin Contract!(TestName("struct.nested.c"), contract_nested);
// @ContractFunction(CodeURL("it.c.compile.struct_", "nested"))
auto contract_nested(TestMode mode, CursorType)(auto ref CursorType tu) {

    tu.kind.expect == Cursor.Kind.TranslationUnit;
    tu.children.expectLength == 1;

    auto outer = tu.child(0);
    outer.isDefinition.expect == true;
    outer.kind.expect == Cursor.Kind.StructDecl;
    outer.spelling.expect == "Outer";
    outer.type.kind.expect == Type.Kind.Record;
    outer.type.spelling.expect == "struct Outer";

    printChildren(outer);
    outer.children.expectLength == 3;


    auto integer = outer.child(0);
    integer.kind.expect == Cursor.Kind.FieldDecl;
    integer.spelling.expect == "integer";
    integer.type.kind.expect == Type.Kind.Int;
    integer.type.spelling.expect == "int";


    auto innerStruct = outer.child(1);
    innerStruct.kind.expect == Cursor.Kind.StructDecl;
    innerStruct.spelling.expect == "Inner";
    innerStruct.type.expectEqual(Type.Kind.Record, "struct Inner");
    innerStruct.type.canonical.expectEqual(Type.Kind.Record, "struct Inner");

    printChildren(innerStruct);
    innerStruct.children.expectLength == 1;  // the `x` field

    auto xfield = innerStruct.child(0);
    xfield.kind.expect == Cursor.Kind.FieldDecl;
    xfield.spelling.expect == "x";
    xfield.type.kind.expect == Type.Kind.Int;


    auto innerField = outer.child(2);
    innerField.kind.expect == Cursor.Kind.FieldDecl;
    innerField.spelling.expect == "inner";
    printChildren(innerField);
    innerField.children.expectLength == 1;  // the Inner StructDecl

    innerField.type.expectEqual(Type.Kind.Elaborated, "struct Inner");
    innerField.type.canonical.expectEqual(Type.Kind.Record, "struct Inner");

    auto innerFieldChild = innerField.child(0);
    innerFieldChild.expect == innerStruct;

    static if(is(CursorType == MockCursor)) return tu;
}


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


// mixin Contract!(TestName("struct.typedef.name"), contract_typedef_name);
// @ContractFunction(CodeURL("it.c.compile.struct_", "typedef.name"))
auto contract_typedef_name(TestMode mode, CursorType)(auto ref CursorType tu) {

    tu.kind.expect == Cursor.Kind.TranslationUnit;
    tu.children.expectLength == 2;

    auto struct_ = tu.child(0);
    struct_.isDefinition.expect == true;
    struct_.kind.expect == Cursor.Kind.StructDecl;
    struct_.spelling.expect == "TypeDefd_";
    struct_.type.kind.expect == Type.Kind.Record;
    struct_.type.spelling.expect == "struct TypeDefd_";

    auto typedef_ = tu.child(1);
    typedef_.isDefinition.expect == true;
    typedef_.kind.expect == Cursor.Kind.TypedefDecl;
    typedef_.spelling.expect == "TypeDefd";
    typedef_.type.kind.expect == Type.Kind.Typedef;
    typedef_.type.spelling.expect == "TypeDefd";

    typedef_.underlyingType.kind.expect == Type.Kind.Elaborated;
    typedef_.underlyingType.spelling.expect == "struct TypeDefd_";
    typedef_.underlyingType.canonical.kind.expect == Type.Kind.Record;
    typedef_.underlyingType.canonical.spelling.expect == "struct TypeDefd_";

    printChildren(typedef_);
    typedef_.children.expectLength == 1;
    typedef_.children[0].expect == struct_;

    static if(is(CursorType == MockCursor)) return tu;
}


// mixin Contract!(TestName("struct.typedef.anon"), contract_typedef_anon);
// @ContractFunction(CodeURL("it.c.compile.struct_", "typedef.anon"))
auto contract_typedef_anon(TestMode mode, CursorType)(auto ref CursorType tu) {

    tu.kind.expect == Cursor.Kind.TranslationUnit;
    tu.children.expectLength == 4;

    {
        auto struct1 = tu.child(0);
        struct1.isDefinition.expect == true;
        struct1.kind.expect == Cursor.Kind.StructDecl;
        struct1.spelling.expect == "";
        struct1.type.kind.expect == Type.Kind.Record;
        // the cursor has no spelling but the type does
        struct1.type.spelling.expect == "Nameless1";

        struct1.children.expectLength == 3;
        struct1.child(0).kind.expect == Cursor.Kind.FieldDecl;
        struct1.child(0).spelling.expect == "x";
        struct1.child(0).type.kind.expect == Type.Kind.Int;
        struct1.child(1).kind.expect == Cursor.Kind.FieldDecl;
        struct1.child(1).spelling.expect == "y";
        struct1.child(1).type.kind.expect == Type.Kind.Int;
        struct1.child(2).kind.expect == Cursor.Kind.FieldDecl;
        struct1.child(2).spelling.expect == "z";
        struct1.child(2).type.kind.expect == Type.Kind.Int;

        auto typedef1 = tu.child(1);
        typedef1.isDefinition.expect == true;
        typedef1.kind.expect == Cursor.Kind.TypedefDecl;
        typedef1.spelling.expect == "Nameless1";
        typedef1.type.kind.expect == Type.Kind.Typedef;
        typedef1.type.spelling.expect == "Nameless1";

        typedef1.underlyingType.kind.expect == Type.Kind.Elaborated;
        typedef1.underlyingType.spelling.expect == "struct Nameless1";
        typedef1.underlyingType.canonical.kind.expect == Type.Kind.Record;
        typedef1.underlyingType.canonical.spelling.expect == "Nameless1";

        printChildren(typedef1);
        typedef1.children.expectLength == 1;
        typedef1.children[0].expect == struct1;
    }

    {
        auto struct2 = tu.child(2);
        struct2.isDefinition.expect == true;
        struct2.kind.expect == Cursor.Kind.StructDecl;
        struct2.spelling.expect == "";
        struct2.type.kind.expect == Type.Kind.Record;
        struct2.type.spelling.expect == "Nameless2";

        struct2.children.expectLength == 1;
        struct2.child(0).kind.expect == Cursor.Kind.FieldDecl;
        struct2.child(0).spelling.expect == "d";
        struct2.child(0).type.kind.expect == Type.Kind.Double;

        auto typedef2 = tu.child(3);
        typedef2.isDefinition.expect == true;
        typedef2.kind.expect == Cursor.Kind.TypedefDecl;
        typedef2.spelling.expect == "Nameless2";
        typedef2.type.kind.expect == Type.Kind.Typedef;
        typedef2.type.spelling.expect == "Nameless2";

        typedef2.underlyingType.kind.expect == Type.Kind.Elaborated;
        typedef2.underlyingType.spelling.expect == "struct Nameless2";
        typedef2.underlyingType.canonical.kind.expect == Type.Kind.Record;
        typedef2.underlyingType.canonical.spelling.expect == "Nameless2";

        printChildren(typedef2);
        typedef2.children.expectLength == 1;
        typedef2.children[0].expect == struct2;
    }

    static if(is(CursorType == MockCursor)) return tu;
}


// mixin Contract!(TestName("struct.typedef.before"), contract_typedef_before);
// @ContractFunction(CodeURL("it.c.compile.struct_", "typedef.before"))
auto contract_typedef_before(TestMode mode, CursorType)(auto ref CursorType tu) {

    tu.kind.expect == Cursor.Kind.TranslationUnit;
    tu.children.expectLength == 3;

    // first, a struct declaration with no definition
    auto struct1 = tu.child(0);
    struct1.isDefinition.expect == false;
    struct1.kind.expect == Cursor.Kind.StructDecl;
    struct1.spelling.expect == "A";
    struct1.type.kind.expect == Type.Kind.Record;
    struct1.type.spelling.expect == "struct A";

    // forward declaration has no children
    struct1.children.expectLength == 0;

    auto typedef_ = tu.child(1);
    typedef_.isDefinition.expect == true;
    typedef_.kind.expect == Cursor.Kind.TypedefDecl;
    typedef_.spelling.expect == "B";
    typedef_.type.kind.expect == Type.Kind.Typedef;
    typedef_.type.spelling.expect == "B";

    typedef_.underlyingType.kind.expect == Type.Kind.Elaborated;
    typedef_.underlyingType.spelling.expect == "struct A";
    typedef_.underlyingType.canonical.kind.expect == Type.Kind.Record;
    typedef_.underlyingType.canonical.spelling.expect == "struct A";

    // then, a struct declaration that is a definition
    auto struct2 = tu.child(2);
    struct2.isDefinition.expect == true;
    struct2.kind.expect == Cursor.Kind.StructDecl;
    struct2.spelling.expect == "A";
    struct2.type.kind.expect == Type.Kind.Record;
    struct2.type.spelling.expect == "struct A";

    // definition has the child
    struct2.children.expectLength == 1;
    auto child = struct2.child(0);

    child.kind.expect == Cursor.Kind.FieldDecl;
    child.spelling.expect == "a";
    child.type.kind.expect == Type.Kind.Int;
    child.type.spelling.expect == "int";

    static if(is(CursorType == MockCursor)) return tu;
}


// TODO: multiple declarations test


@("struct.typedef.normal")
@safe unittest {

    const tu = parse(
        C(
            q{
                typedef struct {
                    int i;
                } Struct;
            }
        )
    );

    tu.children.length.should == 2;

    const structDecl = tu.children[0];
    try
        structDecl.shouldMatch(Cursor.Kind.StructDecl, "");
    catch(Exception _)
        structDecl.shouldMatch(Cursor.Kind.StructDecl, "Struct"); // libclang17

    structDecl.type.shouldMatch(Type.Kind.Record, "Struct");
    printChildren(structDecl);

    structDecl.children.length.should == 1;
    structDecl.children[0].shouldMatch(Cursor.Kind.FieldDecl, "i");
    structDecl.children[0].type.shouldMatch(Type.Kind.Int, "int");

    const typedef_ = tu.children[1];
    typedef_.shouldMatch(Cursor.Kind.TypedefDecl, "Struct");
    typedef_.type.shouldMatch(Type.Kind.Typedef, "Struct");
    printChildren(typedef_);
    typedef_.children.length.should == 1;
    try
        typedef_.children[0].shouldMatch(Cursor.Kind.StructDecl, "");
    catch(Exception _)
        typedef_.children[0].shouldMatch(Cursor.Kind.StructDecl, "Struct"); //libclang17

    typedef_.children[0].type.shouldMatch(Type.Kind.Record, "Struct");
}

@Tags("cpp")
@("struct.typedef.ptr")
@safe unittest {

    const tu = parse(
        C(
            q{
                typedef struct {
                    int i;
                } *Struct;
            }
        )
    );

    tu.children.length.should == 2;

    const structDecl = tu.children[0];
    try
        structDecl.shouldMatch(Cursor.Kind.StructDecl, "");
    catch(Exception _) { //libclang17
        structDecl.kind.should == Cursor.Kind.StructDecl;
        "unnamed".should.be in structDecl.spelling;
    }
    structDecl.type.kind.should == Type.Kind.Record;
    try
        "anonymous at".should.be in structDecl.type.spelling;
    catch (Exception _)
        "unnamed at".should.be in structDecl.type.spelling;

    printChildren(structDecl);

    structDecl.children.length.should == 1;
    structDecl.children[0].shouldMatch(Cursor.Kind.FieldDecl, "i");
    structDecl.children[0].type.shouldMatch(Type.Kind.Int, "int");

    const typedef_ = tu.children[1];
    typedef_.shouldMatch(Cursor.Kind.TypedefDecl, "Struct");
    typedef_.type.shouldMatch(Type.Kind.Typedef, "Struct");
}

@("struct.var.anonymous")
@safe unittest {
    const tu = parse(
        C(`struct { int i; } var;`),
    );

    tu.children.length.should == 2;

    {
        const structDecl= tu.children[0];
        try
            structDecl.shouldMatch(Cursor.Kind.StructDecl, "");
        catch(Exception _) { // libclang17
            structDecl.kind.should == Cursor.Kind.StructDecl;
            "unnamed".should.be in structDecl.spelling;
        }

        printChildren(structDecl);
        structDecl.children.length.should == 1;

        const fieldDecl = structDecl.children[0];
        fieldDecl.shouldMatch(Cursor.Kind.FieldDecl, "i");
        fieldDecl.children.length.should == 0;
    }

    {
        const varDecl = tu.children[1];
        varDecl.shouldMatch(Cursor.Kind.VarDecl, "var");
        varDecl.children.length.should == 1;

        const structDecl = varDecl.children[0];
        try
            structDecl.shouldMatch(Cursor.Kind.StructDecl, "");
        catch(Exception _) { // libclang17
            structDecl.kind.should == Cursor.Kind.StructDecl;
            "unnamed".should.be in structDecl.spelling;
        }
        structDecl.children.length.should == 1;

        const fieldDecl = structDecl.children[0];
        fieldDecl.shouldMatch(Cursor.Kind.FieldDecl, "i");
        fieldDecl.children.length.should == 0;
    }
}

@("enum.var.anonymous")
@safe unittest {
    const tu = parse(
        C(
            q{
                enum {
                    one = 1,
                    two = 2,
                } numbers;
            }
        ),
    );

    tu.children.length.should == 2;

    {
        const enumDecl= tu.children[0];
        try
            enumDecl.shouldMatch(Cursor.Kind.EnumDecl, "");
        catch(Exception _) { // libclang17
            enumDecl.kind.should == Cursor.Kind.EnumDecl;
            "unnamed".should.be in enumDecl.spelling;
        }

        printChildren(enumDecl);
        enumDecl.children.length.should == 2;

        const oneDecl = enumDecl.children[0];
        oneDecl.shouldMatch(Cursor.Kind.EnumConstantDecl, "one");
        oneDecl.children.length.should == 1;

        const twoDecl = enumDecl.children[1];
        twoDecl.shouldMatch(Cursor.Kind.EnumConstantDecl, "two");
        twoDecl.children.length.should == 1;
    }

    {
        const varDecl = tu.children[1];
        varDecl.shouldMatch(Cursor.Kind.VarDecl, "numbers");
        varDecl.children.length.should == 1;

        const enumDecl = varDecl.children[0];
        try
            enumDecl.shouldMatch(Cursor.Kind.EnumDecl, "");
        catch(Exception _) { // libclang17
            enumDecl.kind.should == Cursor.Kind.EnumDecl;
            "unnamed".should.be in enumDecl.spelling;
        }
        enumDecl.children.length.should == 2;

        const oneDecl = enumDecl.children[0];
        oneDecl.shouldMatch(Cursor.Kind.EnumConstantDecl, "one");
        oneDecl.children.length.should == 1;

        const twoDecl = enumDecl.children[1];
        twoDecl.shouldMatch(Cursor.Kind.EnumConstantDecl, "two");
        twoDecl.children.length.should == 1;
    }
}
