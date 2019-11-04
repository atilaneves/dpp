module contract.functions;


import contract;
import std.array: array;


// See #43
@Tags("contract")
@("functionproto.deref")
@safe unittest {

    const tu = parse(
        C(
            q{
                int binOp(int (f)(int x, int y), int a, int b);
            }
        )
    );

    tu.children.length.should == 1;

    const binOp = tu.child(0);
    binOp.shouldMatch(Cursor.Kind.FunctionDecl, "binOp");

    binOp.type.paramTypes.array.length.should == 3;
    const f = binOp.type.paramTypes.array[0];
    // need canonical for old versions of libclang
    f.canonical.shouldMatch(Type.Kind.FunctionProto, "int (int, int)");
    writelnUt(f.pointee);
    // presumably, not a pointer
    f.pointee.isInvalid.should == true;
}


@Tags("contract")
@("functionproto.star")
@safe unittest {

    const tu = parse(
        C(
            q{
                int binOp(int (*f)(int x, int y), int a, int b);
            }
        )
    );

    tu.children.length.should == 1;

    const binOp = tu.child(0);
    binOp.shouldMatch(Cursor.Kind.FunctionDecl, "binOp");

    binOp.type.paramTypes.array.length.should == 3;
    const f = binOp.type.paramTypes.array[0];
    // Even though the declaration here is effectively the same as the
    // one in the test above, it shows up as a pointer
    f.shouldMatch(Type.Kind.Pointer, "int (*)(int, int)");
    writelnUt(f.pointee);
    // it's a pointer
    f.pointee.isInvalid.should == false;

    f.pointee.canonical.shouldMatch(Type.Kind.FunctionProto, "int (int, int)");
}


@Tags("contract")
@("typeof")
@safe unittest {

    const tu = parse(
        C(
            q{
                struct Foo;
                // typeof is a gcc and clang language extension
                typeof(struct Foo *) func();
            }
        )
    );

    tu.children.length.should == 2;

    const func = tu.child(1);
    func.shouldMatch(Cursor.Kind.FunctionDecl, "func");
    printChildren(func);
    func.children.length.should == 1;

    func.returnType.shouldMatch(Type.Kind.Unexposed, "typeof(struct Foo *)");
    func.returnType.canonical.shouldMatch(Type.Kind.Pointer, "struct Foo *");
    func.returnType.canonical.pointee.shouldMatch(Type.Kind.Record, "struct Foo");
}
