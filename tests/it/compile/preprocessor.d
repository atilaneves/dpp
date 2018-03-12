module it.compile.preprocessor;

import it;
import include.runtime;
import std.stdio: File;
import std.format: format;


@("simple macro")
@safe unittest {
    with(const IncludeSandbox()) {

        writeFile("foo.h",
                  q{
                      #define FOO 5
                  });

        writeFile("main.d_", q{
            #include "%s"

            void main() {
                int[FOO] foos;
                static assert(foos.length == 5, "Wrong length for foos");
            }
        }.format(inSandboxPath("foo.h")));

        preprocess!File(inSandboxPath("main.d_"), inSandboxPath("main.d"));
        shouldCompile("main.d");
    }
}

@("define macro, undefine, then define again")
@safe unittest {

    import std.exception: enforce;

    with(immutable IncludeSandbox()) {

        writeFile("header.h",
                  q{
                      #define FOO foo
                      #undef FOO
                      #define FOO bar
                      int FOO(int i);
                  });


        writeFile("foo.d_",
                  q{
                      #include "%s"
                      void func() {
                          int i = bar(2);
                      }
                  }.format(inSandboxPath("header.h")));


        preprocess!File(inSandboxPath("foo.d_"), inSandboxPath("foo.d"));
        shouldCompile("foo.d");
    }
}
