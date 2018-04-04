/**
   C tests that must run
 */
module it.run.c;

import it.run;

@("function named debug")
@safe unittest {
    shouldCompileAndRun(
        C(
            q{
                void debug(const char* msg);
            }
        ),
        C(
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
