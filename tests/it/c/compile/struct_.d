module it.c.compile.struct_;


import it;


@("onefield.int")
@C(
    q{
        struct Foo { int i; };
    }
)
@safe unittest {
    mixin(
        shouldCompile(
            D(
                q{
                    auto f = Foo(5);
                    static assert(f.sizeof == 4, "Wrong sizeof for foo");
                }
            )
        )
    );
}

@("onefield.double")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Bar { double d; };
            }
        ),

        D(
            q{
                auto b = Bar(33.3);
                static assert(b.sizeof == 8, "Wrong sizeof for Bar");
            }
        )
    );
}


@("threefields")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Baz {
                    int i;
                    int j;
                    double d;
                };
            }
        ),

        D(
            q{
                import std.conv: text;
                auto b = Baz(42, 7, 33.3);
                static assert(is(typeof(b.i) == int));
                static assert(is(typeof(b.j) == int));
                static assert(is(typeof(b.d) == double));
                static assert(b.sizeof == 16, text("Wrong sizeof for Baz: ", b.sizeof));
            }
        )
    );
}


@("nested")
@C(
    q{
        struct Outer {
            int integer;
            struct Inner {
                int x;
            } inner;
        };
    }
)
@safe unittest {
    mixin(
        shouldCompile(
            D(
                q{
                    auto o = Outer(77, Outer.Inner(42));
                    static assert(o.sizeof == 8, "Wrong sizeof for Outer");
                }
            )
        )
    );
}


@("typedef.name")
@C(
    q{
        typedef struct TypeDefd_ {
            int i;
            double d;
        } TypeDefd;
    }
)
@safe unittest {
    mixin(
        shouldCompile(
            D(
                q{
                    {
                        auto t = TypeDefd_(42, 33.3);
                        static assert(t.sizeof == 16, "Wrong sizeof for TypeDefd_");
                    }
                    {
                        auto t = TypeDefd(42, 33.3);
                        static assert(t.sizeof == 16, "Wrong sizeof for TypeDefd");
                    }
                }
            )
        )
    );
}


@C(
    q{
        typedef struct {
            int x, y, z;
        } Nameless1;

        typedef struct {
            double d;
        } Nameless2;
    }
)
@("typedef.anon")
@safe unittest {
    mixin(
        shouldCompile(
            D(
                q{
                    auto n1 = Nameless1(2, 3, 4);
                    static assert(n1.sizeof == 12, "Wrong sizeof for Nameless1");
                    static assert(is(typeof(Nameless1.x) == int));
                    static assert(is(typeof(Nameless1.y) == int));
                    static assert(is(typeof(Nameless1.z) == int));

                    auto n2 = Nameless2(33.3);
                    static assert(n2.sizeof == 8, "Wrong sizeof for Nameless2");
                    static assert(is(typeof(Nameless2.d) == double));
                }
            )
        )
    );
}


@C(
    q{
        typedef struct A B;
        struct A { int a; };
    }
)
@("typedef.before")
@safe unittest {
    mixin(
        shouldCompile(
            D(
                q{
                    auto a = A(42);
                    auto b = B(77);
                    static assert(is(A == B));
                }
            )
        )
    );
}


@WIP2
@("fsid_t")
@safe unittest {
    shouldCompile(
        C(
            `
                #define __FSID_T_TYPE struct { int __val[2]; }
                typedef  __FSID_T_TYPE __fsid_t;
                typedef __fsid_t fsid_t;
            `
        ),
        D(
            q{
                fsid_t foo;
                foo.__val[0] = 2;
                foo.__val[1] = 3;
            }
        )
    );
}


@WIP2
@("fd_set")
@safe unittest {

    with(immutable IncludeSandbox()) {

        writeFile("system.h",
                  `
                      #define __FD_SETSIZE 1024
                      typedef long int __fd_mask;
                      #define __NFDBITS (8 * (int) sizeof (__fd_mask))

                      typedef struct
                      {
                       #ifdef __USE_XOPEN
                          __fd_mask fds_bits[__FD_SETSIZE / __NFDBITS];
                       # define __FDS_BITS(set) ((set)->fds_bits)
                       #else
                          __fd_mask __fds_bits[__FD_SETSIZE / __NFDBITS];
                       # define __FDS_BITS(set) ((set)->__fds_bits)
                       #endif
                      } fd_set;
                  `);


        writeFile("header.h",
                  `
                      #include "system.h"
                  `);

        const dppFileName = "foo.dpp";
        writeFile("foo.dpp",
                  `
                      #include "header.h"
                      void func() {
                          fd_set foo;
                          foo.__fds_bits[0] = 5;
                      }
                  `);


        runPreprocessOnly("foo.dpp");
        shouldCompile("foo.d");
    }
}


@("multiple declarations")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct;
                struct Struct;
                struct OtherStruct;
                struct Struct { int x, y, z; };
            }
        ),
        D(
            q{
                Struct s;
                s.x = 42;
                s.y = 33;
                s.z = 77;
                static assert(!__traits(compiles, OtherStruct()));
            }
        )
    );
}


@WIP2
@("var.anonymous")
@safe unittest {
    shouldCompile(
        C(`struct { int i; } var;`),
        D(
            q{
                var.i = 42;
            }
        )
    );
}


@WIP2
@("var.anonymous.typedef")
@safe unittest {
    shouldCompile(
        C(`
              typedef struct { int i; } mystruct;
              mystruct var;
          `),
        D(
            q{
                var.i = 42;
            }
        )
    );
}

@("const anonymous struct as field")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct A {
                    const struct {
                        int version;
                        int other;
                    } version;
                };
            }
        ),
        D(
            q{
                A a = { version_ : { version_ : 13, other : 7 } };
            }
        )
    );
}

@("Pointer to pointer to undeclared struct should result in a struct declaration")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct A {
                    const struct B** p;
                };

                void f(struct C***);
            }
        ),
        D(
            q{
                B *ptrB;
                C *ptrC;
            }
        )
    );
}
