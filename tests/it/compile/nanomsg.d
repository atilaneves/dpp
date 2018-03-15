module it.compile.nanomsg;

import it.compile;

@("nn_get_statistic")
@safe unittest {
    with(const IncludeSandbox()) {

        // the original uses regular uint64_t, let's beat any special cases
        // defining our own
        writeFile("hdr.h",
                  q{
                      typedef unsigned long int __my_uint64_t;
                      typedef __my_uint64_t my_uint64_t;
                      my_uint64_t nn_get_statistic (int s, int stat);
                  });

        writeFile("app.d_",
                  q{
                      #include "%s"
                      void main() {
                          int s;
                          int stat;
                          my_uint64_t ret = nn_get_statistic(s, stat);
                      }
                  }.format(inSandboxPath("hdr.h")));

        preprocess("app.d_", "app.d");
        shouldCompile("app.d");
    }
}
