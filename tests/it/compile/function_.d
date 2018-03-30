module it.compile.function_;

import it.compile;

@("nn_strerror")
@safe unittest {
    shouldCompile(
        C(
            q{
                const char *nn_strerror (int errnum);
            }
        ),

        D(
            q{
                int err = 42;
                const(char)* str = nn_strerror(err);
            }
        ),
    );
}


@("int function(const(char)*)")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef int (*function_t)(const char*);
            }
        ),
        D(
            q{
                int ret = function_t.init("foobar".ptr);
            }
        ),
    );
}

@("const(char)* function(double, int)")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef const char* (*function_t)(double, int);
            }

        ),
        D(
            q{
                const(char)* ret = function_t.init(33.3, 42);
            }
        ),
    );
}

@("void function()")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef void (*function_t)(void);
            }
        ),
        D(
            q{
                import std.traits;
                import std.meta;
                auto f = function_t();
                static assert(is(ReturnType!f == void));
                static assert(is(Parameters!f == AliasSeq!()));
            }
        ),
    );
}

@("variadic")
@safe unittest {
    shouldCompile(
        C(
            q{
                void fun(int, ...);
            }
        ),
        D(
            q{
                fun(42);
                fun(42, 33);
                fun(42, 33.3);
                fun(42, "foobar".ptr);
            }
        ),
    );
}

@("old uts")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Foo { int value; };
                struct Bar { int value; };
                struct Foo addFoos(struct Foo* foo1, struct Foo* foo2);
                struct Bar addBars(const struct Bar* bar1, const struct Bar* bar2);
                const char *nn_strerror (int errnum);
            }
        ),
        D(
            q{

                auto f1 = struct_Foo(2);
                auto f2 = struct_Foo(3);
                struct_Foo f = addFoos(&f1, &f2);
                const b1 = struct_Bar(2);
                const b2 = struct_Bar(3);
                struct_Bar b = addBars(&b1, &b2);
                const(char*) msg = nn_strerror(42);
            }
        ),
    );
}

@("unexposed function pointer variable")
@safe unittest {
    shouldCompile(
        C(
            q{
                int (*func_t) (int, int);
            }
        ),
        D(
            q{
                int res = func_t.init(2, 3);
            }
        ),
    );
}
