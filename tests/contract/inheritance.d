module contract.inheritance;


import contract;


@Tags("contract")
@("single.normal")
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
    typeRef.referencedCursor.should == base;

    printChildren(typeRef);
    typeRef.children.length.should == 0;
}


@Tags("contract")
@("single.template")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                template <typename T>
                struct Base {
                    int i;
                };

                struct Derived: public Base<int> {
                    double d;
                };
            }
        )
    );

    tu.children.length.should == 2;

    const base = tu.child(0);
    base.kind.should == Cursor.Kind.ClassTemplate;
    base.spelling.should == "Base";
    base.type.kind.should == Type.Kind.Invalid;
    base.type.spelling.should == "";

    printChildren(base);
    base.children.length.should == 2; // template type param, field

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
    baseSpec.spelling.should == "Base<int>";
    baseSpec.type.kind.should == Type.Kind.Unexposed; // because it's a template
    baseSpec.type.spelling.should == "Base<int>";
    // Here's where the weirdness starts. We try and get back to the original
    // ClassTemplate cursor here via the baseSpec type, but instead we get a
    // StructDecl. We need to use the TemplateRef instead.
    baseSpec.type.declaration.kind.should == Cursor.Kind.StructDecl;
    baseSpec.type.declaration.spelling.should == "Base";
    baseSpec.type.declaration.children.length.should == 0;

    printChildren(baseSpec);
    baseSpec.children.length.should == 1;

    import clang.c.index;
    const templateRef = baseSpec.child(0);
    templateRef.kind.should == Cursor.Kind.TemplateRef;
    templateRef.spelling.should == "Base";
    templateRef.type.kind.should == Type.Kind.Invalid;
    templateRef.type.spelling.should == "";

    templateRef.referencedCursor.should == base;

    printChildren(templateRef);
    templateRef.children.length.should == 0;
}

@Tags("contract")
@("multiple")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                struct Base0 {
                    int i;
                };

                struct Base1 {
                    int j;
                };

                struct Derived: public Base0, Base1 {
                    double d;
                };
            }
        )
    );

    tu.children.length.should == 3;

    const derived = tu.child(2);
    derived.shouldMatch(Cursor.Kind.StructDecl, "Derived");
    derived.type.shouldMatch(Type.Kind.Record, "Derived");

    printChildren(derived);
    derived.children.length.should == 3;

    const baseSpec0 = derived.child(0);
    baseSpec0.shouldMatch(Cursor.Kind.CXXBaseSpecifier, "struct Base0");
    baseSpec0.type.shouldMatch(Type.Kind.Record, "Base0");
    printChildren(baseSpec0);
    baseSpec0.children.length.should == 1;

    const typeRef0 = baseSpec0.child(0);
    typeRef0.shouldMatch(Cursor.Kind.TypeRef, "struct Base0");
    typeRef0.type.shouldMatch(Type.Kind.Record, "Base0");
    typeRef0.children.length.should == 0;

    const baseSpec1 = derived.child(1);
    baseSpec1.shouldMatch(Cursor.Kind.CXXBaseSpecifier, "struct Base1");
    baseSpec1.type.shouldMatch(Type.Kind.Record, "Base1");
    printChildren(baseSpec1);
    baseSpec1.children.length.should == 1;

    const typeRef1 = baseSpec1.child(0);
    typeRef1.shouldMatch(Cursor.Kind.TypeRef, "struct Base1");
    typeRef1.type.shouldMatch(Type.Kind.Record, "Base1");
    typeRef1.children.length.should == 0;
}


@Tags("contract")
@("using")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                struct Base {
                    Base(int i);
                };

                struct Derived: Base {
                    using Base::Base;
                };
            }
        )
    );

    tu.children.length.should == 2;

    const derived = tu.child(1);
    derived.shouldMatch(Cursor.Kind.StructDecl, "Derived");
    derived.type.shouldMatch(Type.Kind.Record, "Derived");

    printChildren(derived);
    derived.children.length.should == 2;

    const using = derived.child(1);
    using.shouldMatch(Cursor.Kind.UsingDeclaration, "Derived");
    using.type.shouldMatch(Type.Kind.Invalid, "");

    printChildren(using);
    using.children.length.should == 3;

    const typeRef0 = using.child(0);
    typeRef0.shouldMatch(Cursor.Kind.TypeRef, "struct Base");
    typeRef0.type.shouldMatch(Type.Kind.Record, "Base");
    printChildren(typeRef0);
    typeRef0.children.length.should == 0;

    const overloadedDeclRef = using.child(1);
    overloadedDeclRef.shouldMatch(Cursor.Kind.OverloadedDeclRef, "Derived");
    overloadedDeclRef.type.shouldMatch(Type.Kind.Invalid, "");
    overloadedDeclRef.isDefinition.should == false;

    printChildren(overloadedDeclRef);
    overloadedDeclRef.children.length.should == 0;
    overloadedDeclRef.numOverloadedDecls.should == 3;

    // all of the overloads are constructors. The first two are compiler-generated
    const moveCtor = overloadedDeclRef.overloadedDecl(0);
    moveCtor.shouldMatch(Cursor.Kind.Constructor, "Base");
    moveCtor.type.shouldMatch(Type.Kind.FunctionProto, "void (Base &&)");

    const copyCtor = overloadedDeclRef.overloadedDecl(1);
    copyCtor.shouldMatch(Cursor.Kind.Constructor, "Base");
    copyCtor.type.shouldMatch(Type.Kind.FunctionProto, "void (const Base &)");

    const userCtor = overloadedDeclRef.overloadedDecl(2);
    userCtor.shouldMatch(Cursor.Kind.Constructor, "Base");
    userCtor.type.shouldMatch(Type.Kind.FunctionProto, "void (int)");


    const typeRef1 = using.child(2);
    typeRef1.shouldMatch(Cursor.Kind.TypeRef, "struct Base");
    typeRef1.type.shouldMatch(Type.Kind.Record, "Base");
    printChildren(typeRef1);
    typeRef1.children.length.should == 0;
}
