module it.c.compile.preprocessor;

import it;

@("simple macro")
@safe unittest {
    shouldCompile(
        C(
            q{
                #define FOO 5
            }
        ),
        D(
            q{
                int[FOO] foos;
                static assert(foos.length == 5, "Wrong length for foos");
            }
        )
    );
}

@("define macro, undefine, then define again")
@safe unittest {
    shouldCompile(
        C(
            q{
                #define FOO foo
                #undef FOO
                #define FOO bar
                int FOO(int i);
            }
        ),
        D(
            q{
                int i = bar(2);
            }
        )
    );
}
