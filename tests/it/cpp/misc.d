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


@ShouldFail
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
                static assert(is(typeof(var) == int));
            }
        ),
   );
}
