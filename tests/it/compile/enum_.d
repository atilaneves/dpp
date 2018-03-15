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

// TODO: convert to unit test
@ShouldFail("Have to do global variables 1st")
@("named enum with immediate variable declaration")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            enum Numbers {
                one = 1,
                two = 2,
            } numbers;
        });

        writeFile("main.d", q{
            void main() {
                import header;
                numbers = one;
                numbers = two;
                number = Numbers.one;
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

// TODO: convert to unit test
@ShouldFail("Have to do global variables 1st")
@("nameless enum with immediate variable declaration")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            enum {
                one = 1,
                two = 2,
            } numbers;
        });

        writeFile("main.d", q{
            void main() {
                import header;
                numbers = one;
                numbers = two;
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

// TODO: convert to unit test
@("nameless enum inside a struct")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            struct Struct {
                enum {
                    one = 1,
                    two = 2,
                };
            }
        });

        writeFile("main.d", q{
            void main() {
                import header;
                static assert(Struct.two == 2);
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

// TODO: convert to unit test
@ShouldFail("BUG - Uses anonymous enum name to declare variable. Also doesn't declare a variable")
@("nameless enum with variable inside a struct")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            struct Struct {
                enum {
                    one = 1,
                    two = 2,
                } numbers;
            }
        });

        writeFile("main.d", q{
            void main() {
                import header;
                auto s = Struct();
                s.numbers = Struct.one;
            }
        });

        shouldCompile("main.d", "header.d");
    }
}


// TODO: convert to unit test
@("named enum inside a struct")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            struct Struct {
                enum Numbers {
                    one = 1,
                    two = 2,
                };
            }
        });

        writeFile("main.d", q{
            void main() {
                import header;
                static assert(Struct.Numbers.two == 2);
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

// TODO: convert to unit test
@ShouldFail("BUG - Defines an enum instead of a member variable")
@("named enum with variable inside a struct")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("header.d"), In("header.h"), q{
            struct Struct {
                enum Numbers {
                    one = 1,
                    two = 2,
                } numbers;
            }
        });

        writeFile("main.d", q{
            void main() {
                import header;
                auto s = Struct();
                s.numbers = Struct.Numbers.one;
            }
        });

        shouldCompile("main.d", "header.d");
    }
}
