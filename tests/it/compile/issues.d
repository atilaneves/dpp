/**
   Github issues.
 */
module it.compile.issues;

import it.compile;

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
