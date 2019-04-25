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


@("parameter.std.string.rename")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace std {
                    template <typename CharT>
                    struct basic_string {};

                    // naming it string clashes with D's immutable(char)[] alias
                    using mystring = basic_string<char>;
                }

                struct Foo {
                    // the parameter used to get translated as
                    // basic_string without a template parameter
                    void fun(const std::mystring&);
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


@("parameter.std.string.original.nousing")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace std {
                    template<typename CharT>
                    struct char_traits;

                    template<typename T>
                    struct allocator;

                    template <typename CharT, typename Traits = std::char_traits<CharT>, typename Allocator = std::allocator<CharT>>
                    struct basic_string {};

                    // this gets translated as `string` despite the usual
                    // alias to `immutable(char)[]`
                    using string = basic_string<char>;
                }

                struct String {
                    const std::string& value();
                };

                void fun(const std::string&);
            }
        ),
        D(
            q{
                auto str = String();
                fun(str.value);
                auto dstr = "hello";
                static assert(!__traits(compiles, fun(dstr)));
            }
        ),
   );
}


@("parameter.std.string.original.using")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace std {
                    template<typename CharT>
                    struct char_traits;

                    template<typename T>
                    struct allocator;

                    template <typename CharT, typename Traits = std::char_traits<CharT>, typename Allocator = std::allocator<CharT>>
                    struct basic_string {};

                    using string = basic_string<char>;
                }

                /**
                   When this test was written, adding the using
                   directive caused the translation to go from
                   `string` (wrong) to `basic_string!char` (probably
                   not what we want but at least doesn't use the alias
                   for immutable(char)[]).
                 */
                using namespace std;

                struct String {
                    const string& value();
                };

                void fun(const string&);
            }
        ),
        D(
            q{
                auto str = String();
                fun(str.value);
                auto dstr = "hello";
                static assert(!__traits(compiles, fun(dstr)));
            }
        ),
   );
}



@ShouldFail("Cannot currently handle templated opBinary. See dpp.translation.function_.functionDecl FIXME")
@("opBinary")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo {
                    template<typename T>
                    int operator+(const T& other);
                };
            }
        ),
        D(
            q{
                auto foo = Foo();
                int ret = foo + 42;
            }
        ),
   );
}


@("opIndex")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo {
                    int operator[](int i);
                };
            }
        ),
        D(
            q{
                auto foo = Foo();
                int ret = foo[42];
            }
        ),
   );
}


@("opOpAssign")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo {
                    void operator+=(int i);
                };
            }
        ),
        D(
            q{
                auto foo = Foo();
                foo += 42;
            }
        ),
   );
}


@("opBang")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo {
                    bool operator!() const;
                };
            }
        ),
        D(
            q{
                auto foo = Foo();
                bool maybe = !foo;
            }
        ),
   );
}
