/**
   Tests for runtime arguments.
 */
module it.compile.runtime_args;


import it;

@("include paths")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("includes/hdr.h",
                  q{
                      int add(int i, int j);
                  });
        writeFile("main.dpp",
                  q{
                      #include "hdr.h"
                      void main() {
                          int ret = add(2, 3);
                      }
                  });
        run(
            "--preprocess-only",
            "--clang-include-path",
            inSandboxPath("includes"),
            "main.dpp",
        );

        shouldCompile("main.d");
    }
}


@("Output should be a D file")
@safe unittest {
    with(immutable IncludeSandbox()) {

        writeFile("foo.h",
                  q{
                      typedef int foo;
                  });
        writeFile("foo.dpp",
                  q{
                      #include "foo.h"
                  });

        run("--output", "foo.c", "foo.dpp").shouldThrowWithMessage(
            "Output should be a D file (the extension should be .d or .di)");
    }
}

@("Output can be a .d file")
@safe unittest {
    with(immutable IncludeSandbox()) {

        writeFile("foo.h",
                  q{
                      typedef int foo;
                  });
        writeFile("foo.dpp",
                  q{
                      #include "foo.h"
                  });

        run("--output", "foo.d", "foo.dpp");
    }
}

@("Output can be a .di file")
@safe unittest {
    with(immutable IncludeSandbox()) {

        writeFile("foo.h",
                  q{
                      typedef int foo;
                  });
        writeFile("foo.dpp",
                  q{
                      #include "foo.h"
                  });

        run("--output", "foo.di", "foo.dpp");
    }
}
