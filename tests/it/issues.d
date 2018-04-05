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
                silly_name(silly_name.FOO);
            }
        ),
    );
}

@("14")
@safe unittest {
    with(immutable IncludeSandbox()) {

        writeFile("foo.h",
                  q{
                      typedef int foo;
                  });

        run("foo.h", "foo.d").shouldThrowWithMessage(
            "Cannot directly translate C headers. Please run `include` on a D file.");
    }
}
