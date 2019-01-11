module it.cpp.function_;

import it;

@("ref basic param")
unittest {
    shouldCompile(
        Cpp(
            q{
                void fun(int& i);
                void gun(double& i);
            }
        ),
        D(
            q{
                int i;
                fun(i);
                static assert(!__traits(compiles, fun(4)));

                double d;
                gun(d);
                static assert(!__traits(compiles, gun(33.3)));

            }
        ),
   );
}

@("ref struct param")
unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo { int i; double d; };
                void fun(Foo& f);
            }
        ),
        D(
            q{
                auto f = Foo(2, 33.3);
                fun(f);
                static assert(!__traits(compiles, fun(Foo(2, 33.3))));
            }
        ),
   );
}


@("ref basic return")
unittest {
    shouldCompile(
        Cpp(
            q{
                int& fun();
                double& gun();
            }
        ),
        D(
            q{
                auto i = fun();
                static assert(is(typeof(i) == int), typeof(i).stringof);

                auto d = gun();
                static assert(is(typeof(d) == double), typeof(i).stringof);
            }
        ),
   );
}

@("ref struct return")
unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo { int i; };
                Foo& fun();
            }
        ),
        D(
            q{
                auto f = fun();
                static assert(is(typeof(f) == Foo), typeof(i).stringof);
            }
        ),
   );
}


@ShouldFail("Doesn't use the template parameter")
@("parameter.std.string")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace std {
                    template <typename CharT>
                    struct basic_string {};

                    using string = basic_string<char>;
                }

                struct Foo {
                    void fun(const std::string&);
                };
            }
        ),
        D(
            q{
                auto foo = Foo();
            }
        ),
   );
}
