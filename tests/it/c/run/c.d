/**
   C tests that must run
 */
module it.c.run.c;

import it;

@Tags("run")
@("function named debug")
@safe unittest {
    shouldCompileAndRun(
        C(
            q{
                void debug(const char* msg);
            }
        ),
        C(
            `
                #include <stdio.h>
                void debug(const char* msg) { printf("%s\n", msg); }
            `
        ),
        D(
            q{
                debug_("Hello world!\n");
            }
         ),
    );
}


@Tags("run")
@("struct var collision")
@safe unittest {
    shouldCompileAndRun(
        C(
            q{
                struct foo { int dummy; };
                extern int foo;
            }
        ),
        C(
            q{
                int foo;
            }
        ),
        D(
            q{
                auto s = foo(33);
                foo_ = 42;
            }
        ),
    );
}

@Tags("run")
@("struct function collision")
@safe unittest {
    shouldCompileAndRun(
        C(
            q{
                struct foo { int dummy; };
                void foo(void);
            }
        ),
        C(
            q{
                void foo(void) {}
            }
        ),
        D(
            q{
                auto s = foo(33);
                foo_();
            }
        ),
    );
}
