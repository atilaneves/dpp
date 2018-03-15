module it.compile.dstep;

import it.compile;

@("2 functions and a global variable")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("dstep.d"), In("dstep.h"),
               q{
                   float foo(int x);
                   float bar(int x);
                   int a;
               });

        writeFile("main.d",
                  q{
                      import dstep;
                      void main() {
                          float f = foo(42);
                          float b = bar(77);
                          a = 33;
                      }
                  });

        shouldCompile("main.d", "dstep.d");
    }
}
