module it.compile.struct_;

import it;

@("simple int struct")
@safe unittest {
    with(const IncludeSandbox()) {

        expand(Out("header.d"), In("header.h"),
               q{
                   struct Foo { int i; };
               }
        );

        writeFile("main.d", q{
            void main() {
                import header;
                auto f = Foo(5);
                static assert(f.sizeof == 4, "Wrong sizeof for Foo");
            }
        });

        shouldCompile("main.d");
    }
}

@("simple double struct")
@safe unittest {
    with(const IncludeSandbox()) {

        expand(Out("header.d"), In("header.h"),
               q{
                   struct Bar { double d; };
               }
        );

        writeFile("main.d", q{
            void main() {
                import header;
                auto b = Bar(33.3);
                static assert(b.sizeof == 8, "Wrong sizeof for Bar");
            }
        });

        shouldCompile("main.d");
    }
}


@("Outer struct with Inner")
@safe unittest {
    with(const IncludeSandbox()) {

        expand(Out("header.d"), In("header.h"),
               q{
                   struct Outer {
                       struct Inner {
                           int x;
                       } inner;
                   };
               }
        );

        writeFile("main.d", q{
            void main() {
                import header;
                auto o = Outer(Outer.Inner(42));
                static assert(o.sizeof == 4, "Wrong sizeof for Outer");
            }
        });

        shouldCompile("main.d");
    }
}

@("typdef struct with name")
@safe unittest {
    with(const IncludeSandbox()) {

        expand(Out("header.d"), In("header.h"),
               q{
                   typedef struct TypeDefd_ {
                       int i;
                       double d;
                   } TypeDefd;
               }
        );

        writeFile("main.d", q{
            void main() {
                import header;
                {
                    auto t = TypeDefd_(42, 33.3);
                    static assert(t.sizeof == 16, "Wrong sizeof for TypeDefd_");
                }
                {
                    auto t = TypeDefd(42, 33.3);
                    static assert(t.sizeof == 16, "Wrong sizeof for TypeDefd");
                }
            }
        });

        shouldCompile("main.d");
    }
}

@("typdef struct with no name")
@safe unittest {
    with(const IncludeSandbox()) {

        expand(Out("header.d"), In("header.h"),
               q{
                   typedef struct {
                       int x, y, z;
                   } Nameless1;

                   typedef struct {
                       double d;
                   } Nameless2;
               }
        );

        writeFile("main.d", q{
            void main() {
                import header;

                auto n1 = Nameless1(2, 3, 4);
                static assert(n1.sizeof == 12, "Wrong sizeof for Nameless1");

                auto n2 = Nameless2(33.3);
                static assert(n2.sizeof == 8, "Wrong sizeof for Nameless2");
            }
        });

        shouldCompile("main.d");
    }
}
