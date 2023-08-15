module it.cpp.misc;


import it;


@("using alias")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                using foo = int;
            }
        ),
        D(
            q{
                static assert(foo.sizeof == int.sizeof);
                foo f = 42;
            }
        ),
   );
}


@("constexpr.braces")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                constexpr int var{};
            }
        ),
        D(
            q{
                static assert(is(typeof(var) == const(int)));
            }
        ),
   );
}


@("enum.class.decl")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                enum class byte : unsigned char;
            }
        ),
        D(
            q{
            }
        ),
   );
}

@("namespaceless")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace ns {
                    class C1 {
                        public:

                        class C2;
                    };
                }

                using C1_Hidden = ns::C1;

                namespace ns {
                    using _C2 = ::C1_Hidden::C2;
                }
            }
        ),
        D(
            q{
            }
        ),
        [],
   );
}
