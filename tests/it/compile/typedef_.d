module it.compile.typedef_;

import it.compile;

@("unsigned char")
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

@("const char*")
unittest {
    with(const IncludeSandbox()) {
        expand(Out("foo.d"), In("foo.h"),
               q{
                   typedef const char* mystring;
               });
        writeFile("main.d",
                  q{
                      void main() {
                          import foo;
                          const(char)[128] buffer;
                          mystring string_ = &buffer[0];
                      }
                  });
        shouldCompile("main.d", "foo.d");
    }
}
