/**
   Tests for runtime arguments.
 */
module it.compile.runtime_args;


import it.compile;

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
        run("-I", inSandboxPath("includes"), "main.dpp", "main.d");
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

        run("foo.dpp", "foo.c").shouldThrowWithMessage(
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
                      #include "%s"
                  }.format(inSandboxPath("foo.h")));

        run("foo.dpp", "foo.d");
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
                      #include "%s"
                  }.format(inSandboxPath("foo.h")));

        run("foo.dpp", "foo.di");
    }
}
