module contract.aggregates;


import contract;


@("struct.simple")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                struct Struct { int i; };
            }
        )
    );

    tu.children.length.should == 1;
    const struct_ = tu.children[0];
    struct_.kind.should == Cursor.Kind.StructDecl;
    struct_.spelling.should == "Struct";
    struct_.type.kind.should == Type.Kind.Record;
    struct_.type.spelling.should == "Struct";

    printChildren(struct_);
    struct_.children.length.should == 1;
    const member = struct_.children[0];
    member.kind.should == Cursor.Kind.FieldDecl;
    member.spelling.should == "i";

    member.type.kind.should == Type.Kind.Int;
    member.type.spelling.should == "int";
}


@("struct.nested")
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
