/**
   Github issues.
 */
module it.issues;

import it;


@Tags("issue")
@("4")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("issue4.h",
                  q{
                      extern char *arr[9];
                  });
        writeFile("issue4.dpp",
                  `
                   #include "issue4.h"
                  `);
        runPreprocessOnly("issue4.dpp");
        fileShouldContain("issue4.d", q{extern __gshared char*[9] arr;});
    }
}

@Tags("issue")
@("6")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("issue6.h",
                  q{
                      char *getMessage();
                  });
        writeFile("issue6.dpp",
                  `
                   #include "issue6.h"
                  `);
        runPreprocessOnly("issue6.dpp");
        fileShouldContain("issue6.d", q{char* getMessage();});
    }
}


@Tags("issue")
@("10")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum silly_name {
                    FOO,
                    BAR,
                    BAZ,
                };

                extern void silly_name(enum silly_name thingie);
            }
        ),
        D(
            q{
                silly_name_(silly_name.FOO);
            }
        ),
    );
}

@Tags("issue")
@("14")
@safe unittest {
    import dpp.runtime.options: Options;
    with(immutable IncludeSandbox()) {

        writeFile("foo.h",
                  q{
                      typedef int foo;
                  });

        run("foo.h").shouldThrowWithMessage(
            "No .dpp input file specified\n" ~ Options.usage);
    }
}
