module it.compile.array;

import it;

@("1d")
unittest {
    with(const IncludeSandbox()) {

        expand(Out("header.d"), In("header.h"),
               q{
                   struct Foo { int ints[4]; };
               }
        );

        writeFile("main.d", q{
            void main() {
                import header;
                auto f = struct_Foo();
                static assert(f.sizeof == 16, "Wrong sizeof for Foo");
            }
        });

        shouldCompile("main.d", "header.d");
    }
}

@("flexible")
unittest {
    with(const IncludeSandbox()) {

        expand(Out("header.d"), In("header.h"),
               q{
                   struct Slice {
                       int length;
                       unsigned char arr[];
                   };
               }
        );

        writeFile("main.d", q{
            void main() {
                import header;
                auto s = struct_Slice();
                static assert(s.sizeof == 4, "Wrong sizeof for Slice");
            }
        });

        shouldCompile("main.d", "header.d");
    }
}
