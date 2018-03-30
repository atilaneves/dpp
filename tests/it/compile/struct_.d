module it.compile.struct_;

import it.compile;

@("simple int struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Foo { int i; };
            }
        ),
        D(
            q{
                auto f = struct_Foo(5);
                static assert(f.sizeof == 4, "Wrong sizeof for Foo");
            }
        )
    );
}

@("simple double struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Bar { double d; };
            }
        ),

        D(
            q{
                auto b = struct_Bar(33.3);
                static assert(b.sizeof == 8, "Wrong sizeof for Bar");
            }
        )
    );
}


@("Outer struct with Inner")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Outer {
                    struct Inner {
                        int x;
                    } inner;
                };
            }
        ),
        D(
            q{
                auto o = struct_Outer(struct_Outer.struct_Inner(42));
                static assert(o.sizeof == 4, "Wrong sizeof for Outer");
            }
        )
    );
}

@("typedef struct with name")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct TypeDefd_ {
                    int i;
                    double d;
                } TypeDefd;
            }
        ),
        D(
            q{
                {
                    auto t = struct_TypeDefd_(42, 33.3);
                    static assert(t.sizeof == 16, "Wrong sizeof for TypeDefd_");
                }
                {
                    auto t = TypeDefd(42, 33.3);
                    static assert(t.sizeof == 16, "Wrong sizeof for TypeDefd");
                }
            }
        )
    );
}

@("typedef struct with no name")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct {
                    int x, y, z;
                } Nameless1;

                typedef struct {
                    double d;
                } Nameless2;
            }
        ),
        D(
            q{
                auto n1 = Nameless1(2, 3, 4);
                static assert(n1.sizeof == 12, "Wrong sizeof for Nameless1");

                auto n2 = Nameless2(33.3);
                static assert(n2.sizeof == 8, "Wrong sizeof for Nameless2");
            }
        )
    );
}

@("typedef before struct declaration")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct A B;
                struct A { int a; }
            }
        ),
        D(
            q{
                auto a = struct_A(42);
                auto b = B(77);
            }
        )
    );
}

@("fsid_t")
@safe unittest {
    shouldCompile(
        C(
            q{
                #define __FSID_T_TYPE struct { int __val[2]; }
                typedef  __FSID_T_TYPE __fsid_t;
                typedef __fsid_t fsid_t;
            }
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


@("fd_set")
@safe unittest {

    with(immutable IncludeSandbox()) {

        writeFile("system.h",
                  q{
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
                  });


        writeFile("header.h",
                  q{
                      #include "system.h"
                  });

        const inputFileName = "foo.d_";
        writeFile("foo.d_",
                  q{
                      #include "%s"
                      void func() {
                          fd_set foo;
                          foo.__fds_bits[0] = 5;
                      }
                  }.format(inSandboxPath("header.h")));


        preprocess("foo.d_", "foo.d");
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
                struct_Struct s;
                s.x = 42;
                s.y = 33;
                s.z = 77;
                static assert(!__traits(compiles, struct_OtherStruct()));
            }
        )
    );
}
