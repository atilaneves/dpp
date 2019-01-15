module contract.methods;


import contract;


@("header")
@safe unittest {

    const tu = parse(
        Cpp(
            q{
                struct Foo {
                    double fun(int i);
                };

                double Foo::fun(int i) {
                    return i * 2;
                }
            }
        ),
    );

    tu.children.length.should == 2;

    const foo = tu.child(0);
    foo.shouldMatch(Cursor.Kind.StructDecl, "Foo");

    const fun = tu.child(1);
    fun.shouldMatch(Cursor.Kind.CXXMethod, "fun");
    fun.type.shouldMatch(Type.Kind.FunctionProto, "double (int)");
    printChildren(fun);
    fun.children.length.should == 3;

    const typeRef = fun.child(0);
    typeRef.shouldMatch(Cursor.Kind.TypeRef, "struct Foo");

    const param = fun.child(1);
    param.shouldMatch(Cursor.Kind.ParmDecl, "i");

    // this is where the magic happens
    const body_ = fun.child(2);
    body_.shouldMatch(Cursor.Kind.CompoundStmt, "");
    body_.type.shouldMatch(Type.Kind.Invalid, "");
    printChildren(body_);
    body_.children.length.should == 1;

    const return_ = body_.child(0);
    return_.shouldMatch(Cursor.Kind.ReturnStmt, "");
    return_.type.shouldMatch(Type.Kind.Invalid, "");
    printChildren(return_);
    return_.children.length.should == 1;

    const doubleExpr = return_.child(0);
    doubleExpr.shouldMatch(Cursor.Kind.FirstExpr, "");
    doubleExpr.type.shouldMatch(Type.Kind.Double, "double");
    printChildren(doubleExpr);

    // it keeps going after this
}
