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
