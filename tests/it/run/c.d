/**
   C tests that must run
 */
module it.run.c;

import it.run;

@ShouldFail
@("function named debug")
@safe unittest {
    shouldCompileAndRun(
        Cpp(
            q{
                void debug(const char* msg);
            }
        ),
        Cpp(
            q{
                #include <stdio.h>
                void debug(const char* msg) { printf("%s\n", msg); }
            }
        ),
        D(
            q{
                debug_("Hello world!\n");
            }
         ),
    );
}
