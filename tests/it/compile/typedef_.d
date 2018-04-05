module it.compile.typedef_;

import it;

// 0 children
// underlying:           UChar("unsigned char")
// underlying canonical: UChar("unsigned char")
@("unsigned char")
unittest {
    shouldCompile(
        C(
            q{
                typedef unsigned char __u_char;
            }
        ),
        D(
            q{
                static assert(__u_char.sizeof == 1);
            }
        )
    );
}

// 0 children
// underlying:           Pointer("const char *")
// underlying canonical: Pointer("const char *")
@("const char*")
unittest {
    shouldCompile(
        C(
            q{
                typedef const char* mystring;
            }
        ),
        D(
            q{
                const(char)[128] buffer;
            }
        )
    );
}

//  1 child: StructDecl(""), Type.Record("Foo")
// underlying:           Elaborated("struct Foo")
// underlying canonical: Record("Foo")
@("anonymous struct")
unittest {
    shouldCompile(
        C(
            q{
                typedef struct { int i; } Foo;
            }
        ),
        D(
            q{
                Foo f;
                f.i = 42;
                static assert(!__traits(compiles, _Anonymous_1(42)));
            }
        )
    );
}

//  1 child, StructDecl("Foo"), Type.Record("struct Foo")
// underlying:           Elaborated("struct Foo")
// underlying canonical: Record("struct Foo")
@("struct")
unittest {
    shouldCompile(
        C(
            q{
                typedef struct Foo { int i; } Foo;
            }
        ),
        D(
            q{
                Foo f1;
                f1.i = 42;
                Foo f2;
                f2.i = 33;
            }
        )
    );
}

//  1 child, UnionDecl("Foo"), Type.Record("union Foo")
// underlying:           Elaborated("union Foo")
// underlying canonical: Record("union Foo")
@("union")
unittest {
    shouldCompile(
        C(
            q{
                typedef union Foo { int i; } Foo;
            }
        ),
        D(
            q{
                Foo f1;
                f1.i = 42;
                Foo f2;
                f2.i = 33;
            }
        )
    );
}

//  1 child, EnumDecl("Foo"), Type.Enum("enum Foo")
// underlying:           Elaborated("enum Foo")
// underlying canonical: Enum("enum Foo")
@("enum")
unittest {
    shouldCompile(
        C(
            q{
                typedef enum Foo { i } Foo;
            }
        ),
        D(
            q{
                Foo f = Foo.i;
            }
        )
    );
}


// 1 child, IntegerLiteral(""), Type.Int("int")
// underlying:           ConstantArray("int [42]")
// underlying canonical: ConstantArray("int [42]")
@("array")
unittest {
    shouldCompile(
        C(
            q{
                typedef int Array[42];
            }
        ),
        D(
            q{
                Array a;
                static assert(a.sizeof == 42 * int.sizeof);
            }
        )
    );
}

// 0 children
// underling:            Pointer("int *")
// underlying canonical: Pointer("int *")
@("pointer")
unittest {
    shouldCompile(
        C(
            q{
                typedef int* IntPtr;
            }
        ),
        D(
            q{
                int i = 42;
                IntPtr ptr = &i;
            }
        )
    );
}
