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
