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
