/**
   Tests for runtime arguments.
 */
module it.c.compile.runtime_args;


import it;

@("include paths")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("includes/hdr.h",
                  q{
                      int add(int i, int j);
                  });
        writeFile("main.dpp",
                  `
                      #include "hdr.h"
                      void main() {
                          int ret = add(2, 3);
                      }
                  `);
        runPreprocessOnly(
            "--include-path",
            inSandboxPath("includes"),
            "main.dpp",
        );

        shouldCompile("main.d");
    }
}
