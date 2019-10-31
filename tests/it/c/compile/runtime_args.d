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

@("rewritten module name")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("pretend-windows.h",
                ``);
        writeFile("hdr.h",
                  `
                      #include "pretend-windows.h"
                  `);
        writeFile("main.dpp",
                  `
                      #include "hdr.h"
                      void main() {
                          writeln(""); // should have imported by include translation
                      }
                  `);
        runPreprocessOnly(
            "--prebuilt-header",
            "pretend-windows.h=std.stdio",
            "main.dpp",
        );

        shouldCompile("main.d");
    }
}

@("ignored paths")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("pretend-windows.h",
                `
                    #define foo "foo"
                `);
        writeFile("hdr.h",
                  `
                      #include "pretend-windows.h"
                  `);
        writeFile("main.dpp",
                  `
                      #include "hdr.h"
                      void main() {
                          static assert(!is(typeof(foo)));
                      }
                  `);
        runPreprocessOnly(
            "--ignore-path",
            "*pretend-windows.h",
            "main.dpp",
        );

        shouldCompile("main.d");
    }
}

@("ignored system paths")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("main.dpp",
                  `
                      #include <stdio.h>
                      // since the system path is ignored, the declarations
                      // should NOT have been generated here
                      void main() {
                          static assert(!is(typeof(printf)));
                      }
                  `);
        runPreprocessOnly(
            "--ignore-system-paths",
            "main.dpp",
        );

        shouldCompile("main.d");
    }
}
