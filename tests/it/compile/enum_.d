module it.compile.enum_;

import it.compile;

@("Named enum with non-assigned members foo and bar")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            enum Foo {
                foo,
                bar
            };
        });

        writeFile("main.d", q{
            void main() {
                import header;
                static assert(foo == 0);
                static assert(bar == 1);
                static assert(Foo.foo == 0);
                static assert(Foo.bar == 1);
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

@("Named enum with non-assigned members quux and toto")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            enum Enum {
                quux,
                toto
            };
        });

        writeFile("main.d", q{
            void main() {
                import header;
                static assert(quux == 0);
                static assert(toto == 1);
                static assert(Enum.quux == 0);
                static assert(Enum.toto == 1);
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

@("Named enum with assigned members foo, bar, baz")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            enum FooBarBaz {
                foo = 2,
                bar = 5,
                baz = 7
            };
        });

        writeFile("main.d", q{
            void main() {
                import header;
                static assert(foo == 2);
                static assert(bar == 5);
                static assert(baz == 7);
                static assert(FooBarBaz.foo == 2);
                static assert(FooBarBaz.bar == 5);
                static assert(FooBarBaz.baz == 7);
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

// TODO: convert to unit test
@("typedef nameless enum")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            typedef enum {
                foo = 2,
                bar = 5,
                baz = 7
            } FooBarBaz;
        });

        writeFile("main.d", q{
            void main() {
                import header;
                static assert(bar == 5);
                static assert(FooBarBaz.baz == 7);
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

// TODO: convert to unit test
@("typedef named enum")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            typedef enum FooBarBaz_ {
                foo = 2,
                bar = 5,
                baz = 7
            } FooBarBaz;
        });

        writeFile("main.d", q{
            void main() {
                import header;
                static assert(FooBarBaz_.foo == 2);
                static assert(bar == 5);
                static assert(FooBarBaz.baz == 7);
            }
        });

        shouldCompile("main.d", "header.d");
    }
}
