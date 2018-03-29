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
                static assert(enum_Foo.foo == 0);
                static assert(enum_Foo.bar == 1);
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
                static assert(enum_Enum.quux == 0);
                static assert(enum_Enum.toto == 1);
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
                static assert(enum_FooBarBaz.foo == 2);
                static assert(enum_FooBarBaz.bar == 5);
                static assert(enum_FooBarBaz.baz == 7);
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
                static assert(enum_FooBarBaz_.foo == 2);
                static assert(bar == 5);
                static assert(FooBarBaz.baz == 7);
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

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
                numbers = cast(enum_Numbers)one;
                numbers = cast(enum_Numbers)two;
                numbers = enum_Numbers.one;
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

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
                numbers = cast(typeof(numbers))one;
                numbers = cast(typeof(numbers))two;
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
                static assert(struct_Struct.two == 2);
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

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
                auto s = struct_Struct();
                s.numbers = cast(typeof(s.numbers)) struct_Struct.one;
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
                static assert(struct_Struct.enum_Numbers.two == 2);
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

// TODO: convert to unit test
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
                auto s = struct_Struct();
                s.numbers = struct_Struct.enum_Numbers.one;
            }
        });

        shouldCompile("main.d", "header.d");
    }
}
