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
