module it.c.compile.enum_;

import it;

@("Named enum with non-assigned members foo and bar")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum Foo {
                    foo,
                    bar
                };
            }
        ),

        D(
            q{
                static assert(is(typeof(foo) == Foo));
                static assert(is(typeof(bar) == Foo));
                static assert(foo == 0);
                static assert(bar == 1);
                static assert(Foo.foo == 0);
                static assert(Foo.bar == 1);
            }
        ),

    );}

@("Named enum with non-assigned members quux and toto")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum Enum {
                    quux,
                    toto
                };
            }
        ),

        D(
            q{
                static assert(is(typeof(quux) == Enum));
                static assert(is(typeof(toto) == Enum));
                static assert(quux == 0);
                static assert(toto == 1);
                static assert(Enum.quux == 0);
                static assert(Enum.toto == 1);
            }
        ),

    );}

@("Named enum with assigned members foo, bar, baz")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum FooBarBaz {
                    foo = 2,
                    bar = 5,
                    baz = 7
                };
            }
        ),

        D(
            q{
                static assert(is(typeof(foo) == FooBarBaz));
                static assert(is(typeof(bar) == FooBarBaz));
                static assert(is(typeof(baz) == FooBarBaz));
                static assert(foo == 2);
                static assert(bar == 5);
                static assert(baz == 7);
                static assert(FooBarBaz.foo == 2);
                static assert(FooBarBaz.bar == 5);
                static assert(FooBarBaz.baz == 7);
            }
        ),

    );
}

// TODO: convert to unit test
@("typedef nameless enum")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef enum {
                    foo = 2,
                    bar = 5,
                    baz = 7
                } FooBarBaz;
            }
        ),

        D(
            q{
                static assert(is(typeof(bar) == FooBarBaz));
                static assert(bar == 5);
                static assert(FooBarBaz.baz == 7);
            }
        ),

    );}

// TODO: convert to unit test
@("typedef named enum")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef enum FooBarBaz_ {
                    foo = 2,
                    bar = 5,
                    baz = 7
                } FooBarBaz;
            }
        ),

        D(
            q{

                static assert(is(typeof(bar) == FooBarBaz_));
                static assert(FooBarBaz_.foo == 2);
                static assert(bar == 5);
                static assert(FooBarBaz.baz == 7);
            }
       ),

    );
}

@("named enum with immediate variable declaration")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum Numbers {
                    one = 1,
                    two = 2,
                } numbers;
            }
        ),

        D(
            q{

                static assert(is(typeof(one) == Numbers));
                static assert(is(typeof(two) == Numbers));
                numbers = one;
                numbers = two;
                numbers = Numbers.one;
            }
        ),

    );
}

@("nameless enum with immediate variable declaration")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum {
                    one = 1,
                    two = 2,
                } numbers;
            }
        ),

        D(
            q{
                static assert(is(typeof(one) == typeof(numbers)));
                static assert(is(typeof(two) == typeof(numbers)));
                numbers = one;
                numbers = two;
            }
        ),

    );
}

// TODO: convert to unit test
@("nameless enum inside a struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    enum {
                        one = 1,
                        two = 2,
                    };
                };
            }
        ),

        D(
            q{

                static assert(is(typeof(Struct.one) == enum));
                static assert(Struct.two == 2);
            }
        ),

    );
}

@("nameless enum with variable inside a struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    enum {
                        one = 1,
                        two = 2,
                    } numbers;
                };
            }
        ),

        D(
            q{
                auto s = Struct();
                static assert(is(typeof(s.one) == typeof(s.numbers)));
                s.numbers = Struct.one;
            }
        ),

    );
}


// TODO: convert to unit test
@("named enum inside a struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    enum Numbers {
                        one = 1,
                        two = 2,
                    };
                };
            }
        ),

        D(
            q{
                static assert(is(typeof(Struct.one) == Struct.Numbers));
                static assert(Struct.Numbers.two == 2);
            }
        ),

    );
}

// TODO: convert to unit test
@("named enum with variable inside a struct")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    enum Numbers {
                        one = 1,
                        two = 2,
                    } numbers;
                };
            }
        ),

        D(
            q{
                static assert(is(typeof(Struct.one) == Struct.Numbers));
                static assert(is(typeof(Struct.numbers) == Struct.Numbers));
                auto s = Struct();
                s.numbers = Struct.Numbers.one;
            }
        ),
    );
}

@("call and return enums")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum Enum { one, two, three };
                enum Enum fun(int, int);
                void gun(enum Enum);
            }
         ),

        D(
            q{
                Enum e = fun(42, 33);
                gun(two);
            }
         ),
    );
}


@("rename")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum FancyWidget { Widget_foo,  Widget_bar };
            }
         ),

        D(
            q{
                mixin dpp.EnumD!("Widget", FancyWidget, "Widget_");
                static assert(cast(FancyWidget) Widget.foo == Widget_foo);
                static assert(cast(FancyWidget) Widget.foo == FancyWidget.Widget_foo);
                static assert(cast(FancyWidget) Widget.bar == Widget_bar);
                static assert(cast(FancyWidget) Widget.bar == FancyWidget.Widget_bar);
            }
         ),
    );
}


@("keyword")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum Enum { debug, other };
            }
         ),

        D(
            q{
                auto d = Enum.debug_;
                auto o = Enum.other;
            }
         ),
    );
}

@("enumBaseType changed to long")
@safe unittest {
    shouldCompile(
        C(
            `
                #include <limits.h>
                enum Promoted { A = 1, B = LONG_MAX };
                enum NotPromoted { C = 1, D = 3 };
            `
         ),

        D(
            q{
                import core.stdc.config : c_long;
                auto a = Promoted.A;
                auto b = Promoted.B;
                static assert(c_long.max == Promoted.B);
                static assert(Promoted.sizeof == c_long.sizeof);
                static assert(NotPromoted.sizeof == int.sizeof);
            }
         ),
    );
}
