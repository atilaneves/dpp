/**
   Integration tests that stem from failues in real-life C projects
 */
module it.compile.projects;

import it.compile;

@("nn_get_statistic")
@safe unittest {
    with(const IncludeSandbox()) {

        // the original uses regular uint64_t, let's beat any special cases
        // defining our own
        expand(Out("hdr.d"), In("hdr.h"),
                  q{
                      typedef unsigned long int __my_uint64_t;
                      typedef __my_uint64_t my_uint64_t;
                      my_uint64_t nn_get_statistic (int s, int stat);
                  });

        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          int s;
                          int stat;
                          my_uint64_t ret = nn_get_statistic(s, stat);
                      }
                  });

        shouldCompile("app.d", "hdr.d");
    }
}

@("__io_read_fn")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
                  q{
                      typedef long long __ssize_t;
                      typedef __ssize_t __io_read_fn (void *__cookie, char *__buf, size_t __nbytes);
                  });

        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          void* cookie;
                          char[1024] buf;
                          __ssize_t ret = __io_read_fn.init(cookie, buf.ptr, buf.length);
                      }
                  });

        shouldCompile("app.d", "hdr.d");
    }
}
