/**
   Github issues.
 */
module it.issues;

import it;


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

@("14")
@safe unittest {
    import include.runtime.options: Options;
    with(immutable IncludeSandbox()) {

        writeFile("foo.h",
                  q{
                      typedef int foo;
                  });

        run("foo.h").shouldThrowWithMessage(
            "No .dpp input file specified\n" ~ Options.usage);
    }
}
