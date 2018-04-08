/**
   Tests "inspired" by the ones in dstep's functional directory
 */
module it.c.dstep.functional;

import it;

@("const int")
@safe unittest {
    shouldCompile(
        C(
            q{
                const int a; // const int
                const int* b; // mutable pointer to const int
                int* const c; // const pointer to mutable int
                const int* const d; // const pointer to const int
                const int* const * e; // mutable pointer to const pointer to const int
                const int* const * const f; // const pointer to const pointer to const int
                int* const * const g; // const pointer to const pointer to mutable int
            }
        ),
        D(
            q{
                void assertType(E, A, string file = __FILE__, size_t line = __LINE__)
                    (auto ref A t)
                {
                    import std.conv: text;
                    static assert(is(A == E),
                                  text(file, ":", line, " Expected: ", E.stringof,
                                       "  Got: ", A.stringof));
                }

                assertType!(const int)(a);
                assertType!(const(int)*)(b);
                assertType!(int*)(c);
                assertType!(const int*)(d);
                assertType!(const(int*)*)(e);
                assertType!(const int**)(f);
                assertType!(int**)(g);
            }
        ),
    );
}

@("const struct")
@safe unittest {

    shouldCompile(
        C(
            q{
                typedef struct { int i; } Struct;
                const Struct a; // const Struct
                const Struct* b; // mutable pointer to const Struct
                Struct* const c; // const pointer to mutable Struct
                const Struct* const d; // const pointer to const Struct
                const Struct* const * e; // mutable pointer to const pointer to const Struct
                const Struct* const * const f; // const pointer to const pointer to const Struct
                Struct* const * const g; // const pointer to const pointer to mutable Struct
            }
        ),
        D(
            q{
                void assertType(E, A, string file = __FILE__, size_t line = __LINE__)
                    (auto ref A t)
                {
                    import std.conv: text;
                    static assert(is(A == E),
                                  text(file, ":", line, " Expected: ", E.stringof,
                                       "  Got: ", A.stringof));
                }

                assertType!(const Struct)(a);
                assertType!(const(Struct)*)(b);
                assertType!(Struct*)(c);
                assertType!(const Struct*)(d);
                assertType!(const(Struct*)*)(e);
                assertType!(const Struct**)(f);
                assertType!(Struct**)(g);
            }
        ),
    );
}

@("dynamic")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct
                {
                    int x;
                    int data[0];
                } Dynamic;
            }
        ),
        D(
            q{
                import core.stdc.stdlib: malloc;
                auto d = cast(Dynamic*)malloc(Dynamic.sizeof + 5 * int.sizeof);
                d.x = 42;
                // out of bounds
                static assert(!__traits(compiles, d.data[3]));
                auto ptr = d.data.ptr;
                ptr[3] = 77;
            }
        ),
    );
}

@("function_pointers")
@safe unittest {
    shouldCompile(
        C(
            q{
                void (*a) (void);
                int (*b) (void);
                void (*c) (int);
                int (*d) (int, int);
                int (*e) (int a, int b);
                int (*f) (int a, int b, ...);
            }
        ),
        D(
            q{
                static assert(is(typeof(a()) == void));
                static assert(is(typeof(b()) == int));
                c(42);
                int dres = d(2, 3);
                int eres = e(4, 5);
                int fres = f(6, 7, 9.0, null);
                static assert(!__traits(compiles, f.init(6)));
                static assert(!__traits(compiles, f.init(6, 9.0)));
            }
        ),
    );
}
