module it.compile.array;

import it;

@("struct with 1d array")
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
                auto f = Foo();
                static assert(f.sizeof == 16, "Wrong sizeof for Foo");
            }
        });

        shouldCompile("main.d");
    }

}
