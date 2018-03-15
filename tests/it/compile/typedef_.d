module it.compile.typedef_;

import it.compile;

@("typedef to unsigned char")
unittest {
    with(const IncludeSandbox()) {
        expand(Out("foo.d"), In("foo.h"),
               q{
                   typedef unsigned char __u_char;
               });
        writeFile("main.d",
                  q{
                      void main() {
                          import foo;
                          static assert(__u_char.sizeof == 1);
                      }
                  });
        shouldCompile("main.d", "foo.d");
    }
}
