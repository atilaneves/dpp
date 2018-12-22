module contract.inheritance;


import contract;


@Tags("contract")
@("struct.single")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                struct Base {
                    int i;
                };

                struct Derived: public Base {
                    double d;
                };
            }
        )
    );

    tu.children.length.should == 2;

    const base = tu.child(0);
    base.kind.should == Cursor.Kind.StructDecl;
    base.spelling.should == "Base";
    base.type.kind.should == Type.Kind.Record;
    base.type.spelling.should == "Base";

    printChildren(base);
    base.children.length.should == 1;

    const derived = tu.child(1);
    derived.kind.should == Cursor.Kind.StructDecl;
    derived.spelling.should == "Derived";
    derived.type.kind.should == Type.Kind.Record;
    derived.type.spelling.should == "Derived";

    printChildren(derived);
    derived.children.length.should == 2;

    const j = derived.child(1);
    j.kind.should == Cursor.Kind.FieldDecl;

    const baseSpec = derived.child(0);
    baseSpec.kind.should == Cursor.Kind.CXXBaseSpecifier;
    baseSpec.spelling.should == "struct Base";
    baseSpec.type.kind.should == Type.Kind.Record;
    baseSpec.type.spelling.should == "Base";

    printChildren(baseSpec);
    baseSpec.children.length.should == 1;

    const typeRef = baseSpec.child(0);
    typeRef.kind.should == Cursor.Kind.TypeRef;
    typeRef.spelling.should == "struct Base";
    typeRef.type.kind.should == Type.Kind.Record;
    typeRef.type.spelling.should == "Base";

    printChildren(typeRef);
    typeRef.children.length.should == 0;
}
