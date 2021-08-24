module it.c.compile.typedef_;

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

@("typedef multiple definitions")
@safe unittest {
    // See https://github.com/tpn/winsdk-10/blob/9b69fd26ac0c7d0b83d378dba01080e93349c2ed/Include/10.0.16299.0/um/winscard.h#L504-L528
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h",
                `
                    typedef struct {
                        int dwStructSize;
                        int lpstrGroupNames;
                    } a, *b, *c;

                    typedef struct {
                        int dwStructSize;
                        int lpstrGroupNames;
                    } x, *y, *z;

                    #ifdef SOMETHING
                    typedef x X;
                    typedef y Y;
                    typedef z Z;
                    #else
                    typedef a X;
                    typedef b Y;
                    typedef c Z;
                    #endif
                `);

        writeFile("main.dpp",
                `
                    #include "hdr.h"
                    void main() { }
                `);

        runPreprocessOnly("main.dpp");

        shouldCompile("main.d");
    }
}


@("check anonymous struct is defined")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h",
                `
                    typedef struct {
                        void * pad[2];
                        void * userContext;
                    } * NDR_SCONTEXT;

                    typedef struct A {
                        NDR_SCONTEXT k;
                    };
                `);

        writeFile("main.dpp",
                `
                    #include "hdr.h"
                    void main() { }
                `);

        runPreprocessOnly("main.dpp");

        shouldCompile("main.d");
    }
}

@("anon struct declaration should be missing")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h",
                `
                    typedef struct {
                        void * pad[2];
                        void * userContext;
                    } * NDR_SCONTEXT;

                    typedef struct A {
                        NDR_SCONTEXT * k;
                    };

                    void test(NDR_SCONTEXT * x);
                `);

        writeFile("main.dpp",
                `
                    #include "hdr.h"
                    void main() { }
                `);

        runPreprocessOnly("main.dpp");

        shouldCompile("main.d");
    }
}
