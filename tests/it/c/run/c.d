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

@Tags("run")
@("static.inline")
@safe unittest {
    shouldCompileAndRun(
        C(
            `
                static inline int _add(int i, int j) {
                    return i + j;
                }
                #define add(i, j) _add(i, j)
            `
        ),
        C(
            q{
            }
        ),
        D(
            q{
                // this is a workaround for not translating the static inline function
                int _add(int i, int j) { return i + j + 1; }
                assert(add(2, 3) == 6);
            }
        ),
    );
}
