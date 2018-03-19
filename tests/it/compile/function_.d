module it.compile.function_;

import it.compile;

@("nn_strerror")
@safe unittest {
    with(const IncludeSandbox()) {

        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   const char *nn_strerror (int errnum);
               });

        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          int err = 42;
                          const(char)* str = nn_strerror(err);
                      }
                  });

        shouldCompile("app.d", "hdr.d");
    }
}


@("int function(const(char)*)")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef int (*function_t)(const char*);
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      void maid() {
                          int ret = function_t.init("foobar".ptr);
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}

@("const(char)* function(double, int)")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef const char* (*function_t)(double, int);
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      void maid() {
                          const(char)* ret = function_t.init(33.3, 42);
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}
