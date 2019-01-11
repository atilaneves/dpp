/**
   Member pointers
 */
module contract.member;


import contract;


@Tags("contract")
@("member object pointer")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                struct Struct { int i; };
                int Struct::* globalStructInt;
            }
        )
    );

    tu.children.length.shouldEqual(2);

    const struct_  = tu.children[0];
    struct_.kind.should == Cursor.Kind.StructDecl;

    const global = tu.children[1];
    global.kind.should == Cursor.Kind.VarDecl;

    const globalType = global.type;
    globalType.kind.should == Type.Kind.MemberPointer;

    const pointee = globalType.pointee;
    pointee.kind.should == Type.Kind.Int;
}



@Tags("contract")
@("private")
@safe unittest {
    import clang: AccessSpecifier;

    const tu = parse(
        Cpp(
            q{
                struct Struct {
                private:
                    int i;
                public:
                    int j;
                };
            }
        )
    );

    tu.children.length.should == 1;
    const struct_ = tu.child(0);
    printChildren(struct_);
    struct_.children.length.should == 4;

    const private_ = struct_.child(0);
    private_.shouldMatch(Cursor.Kind.CXXAccessSpecifier, "");
    private_.type.shouldMatch(Type.Kind.Invalid, "");
    private_.children.length.should == 0;
    private_.accessSpecifier.should == AccessSpecifier.Private;

    const i = struct_.child(1);
    i.shouldMatch(Cursor.Kind.FieldDecl, "i");
    i.type.shouldMatch(Type.Kind.Int, "int");

    const public_ = struct_.child(2);
    public_.shouldMatch(Cursor.Kind.CXXAccessSpecifier, "");
    public_.type.shouldMatch(Type.Kind.Invalid, "");
    public_.children.length.should == 0;
    public_.accessSpecifier.should == AccessSpecifier.Public;

    const j = struct_.child(3);
    j.shouldMatch(Cursor.Kind.FieldDecl, "j");
    j.type.shouldMatch(Type.Kind.Int, "int");
}
