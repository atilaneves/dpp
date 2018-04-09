/**xpand
   Tests "inspired" by the ones in dstep's UnitTests.d module
 */
module it.c.dstep.ut;

import it;


@("2 functions and a global variable")
@safe unittest {
    shouldCompile(
        C(q{
                float foo(int x);
                float bar(int x);
                int a;
            }
        ),
        D(

            q{
                float f = foo(42);
                float b = bar(77);
                a = 33;
            }
        ),
    );

}

@("extern int declared several times")
@safe unittest {
    shouldCompile(
        C(
            q{
                extern int foo;
                extern int bar;
                extern int foo;
                extern int foo;
            }
        ),
        D(

            q{
                foo = 5;
                bar = 3;
            }
        ),
    );
}

@("array with #defined length")
@safe unittest {
    shouldCompile(
        C(
            `
              #define FOO 4
              char var[FOO];
          `
        ),
        D(
            q{
                static assert(var.sizeof == 4);
                var[0] = cast(byte)3;
            }
        ),
    );
}

@("struct with array with #defined length")
@safe unittest {
    shouldCompile(
        C(
            `
                #define BAR 128

                struct Foo {
                    char var[BAR];
                };
            `
        ),
        D(
            q{
                auto f = Foo();
                static assert(f.var.sizeof == 128);
                f.var[127] = cast(byte)3;
            }
        ),
    );
}


@("struct with 3d arrays of #defined length")
@safe unittest {
    shouldCompile(
        C(
            `
                #define FOO 2
                #define BAR 4
                #define BAZ 8

                struct Foo {
                    char var[FOO][BAR][BAZ];
                };
            `
        ),
        D(
            q{
                auto f = Foo();
                // opposite order than in C
                static assert(f.var.length == 2);
                static assert(f.var[0].length == 4);
                static assert(f.var[0][0].length == 8);
                auto v = f.var[0][0][7];
            }
        ),
    );
}

@("nested anonymous structures")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct C {
                    struct {
                        int x;
                        int y;

                        struct {
                            int z;
                            int w;
                        } nested;
                    } point;
                };
            }
        ),
        D(

            q{
                auto c = C();
                c.point.x = 42;
                c.point.y = 77;
                c.point.nested.z = 2;
                c.point.nested.w = 3;
            }
        ),
    );

}

@("interleaved enum-based array size consts and macro based array size counts")
@safe unittest {
    shouldCompile(
        C(
            `
                struct qux {
                    char scale;
                };

                #define FOO 2
                #define BAZ 8

                struct stats_t {
                    enum
                    {
                        BAR = 4,
                    };

                    struct qux stat[FOO][BAR][FOO][BAZ];
                };
            `
        ),
        D(
            q{
                auto s = stats_t();
                // opposite order than in C
                static assert(stats_t.BAR == 4);
                // accessing at the limits of each dimension
                auto q = s.stat[1][3][1][7];
            }
        ),
    );
}

@("function pointer with unnamed parameter")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef int (*read_char)(void *);
            }
        ),
        D(

            q{
                read_char func;
                int val;
                int ret = func(&val);
            }
        ),
    );

}

@("array typedef")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef double foo[2];
            }
        ),
        D(

            q{
                foo doubles;
                static assert(doubles.length == 2);
                doubles[0] = 33.3;
                doubles[1] = 77.7;
            }
        ),
    );

}

@("array of structs declared immediately")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Foo {
                    struct Bar {
                    } bar[64];
                };
            }
        ),
        D(

            q{
                auto f = Foo();
                static assert(f.bar.length == 64);
                f.bar[63] = Foo.Bar();
            }
        ),
    );

}

@("variadic function without ...")
@safe unittest {

    shouldCompile(
        C(
            q{
                // Since fully variadic C functions aren't allowed in D,
                // we assume the header means `void foo(void);`
                // The reason being that void foo(...) wouldn't compile
                // anyway and it's possible they meant foo(void).
                void foo();
            }
        ),
        D(
            q{
                foo();
                static assert(!__traits(compiles, foo(2, 3)));
            }
        ),
    );
}


@("function pointers")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef void* ClientData;
                typedef struct { int dummy; } EntityInfo;
                void (*fun)(ClientData client_data, const EntityInfo*, unsigned last);
            }
        ),
        D(

            q{
                auto eInfo = EntityInfo(77);
                struct Data { int value; }
                auto data = Data(42);
                uint last = 33;
                fun(&data, &eInfo, last);
            }
        ),
    );

}


@("array function parameters")
@safe unittest {
    shouldCompile(
        C(
            q{
                int foo (int data[]);             // int*
                int bar (const int data[]);       // const int*
                int baz (const int data[32]);     // const int*
                int qux (const int data[32][64]); // const int(*)[64]
            }
        ),
        D(

            q{
                int* data;
                foo(data);
                bar(data);
                baz(data);

                const(int)* cdata;
                static assert(!__traits(compiles, foo(cdata)));
                bar(cdata);
                baz(cdata);

                static assert(!__traits(compiles, qux(data)));
                static assert(!__traits(compiles, qux(cdata)));
                const(int)[64] arr;
                qux(&arr);
            }
        ),
    );

}

@("name collision between struct and function")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct foo;
                struct foo { int i; };
                void foo(void);
            }
        ),
        D(

            q{
                foo f;
                f.i = 42;
                foo_();
            }
        ),
    );

}

@("name collision between struct and enum")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum foo { FOO };
                void foo(void);
            }
        ),
        D(

            q{
                foo_();
                auto f1 = FOO;
                foo f2 = foo.FOO;
            }
        ),
    );

}

@("function parameter of elaborate type")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct foo_t { int i; };
                void bar(const struct foo_t *foo);
            }
        ),
        D(

            q{
                auto f = foo_t(42);
                bar(&f);
                const cf = const foo_t(33);
                bar(&cf);
            }
        ),
    );

}

@("packed struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Foo {
                    char x;
                    short y;
                    int z;
                } __attribute__((__packed__));
            }
        ),
        D(
            q{
                static assert(Foo.sizeof == 7, "Foo should be 7 bytes");
            }
        ),
    );
}
