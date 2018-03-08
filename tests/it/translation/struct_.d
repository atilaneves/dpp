module it.translation.struct_;

import it.translation;

@("two structs")
@safe unittest {
    with(const TranslationSandbox()) {

        expand(Out("foo.d"), In("foo.h"),
               q{
                   struct Foo { int i; };
                   struct Bar { double d; };
                   struct Outer {
                       struct Inner {
                           int x;
                       } inner;
                   };
               }
        );

        writeFile("main.d", q{
            import foo;
            void main() {

                auto f = Foo(5);
                assert(f.sizeof == 4, "Wrong sizeof for Foo");
                assert(f.i == 5, "f.i should be 5");

                auto b = Bar(33.3);
                assert(b.sizeof == 8, "Wrong sizeof for Foo");
                assert(b.d == 33.3, "b.d should be 33.3");

                auto o = Outer(Outer.Inner(42));
                assert(o.sizeof == 4);
                assert(o.inner.x == 42);
            }
        });

        shouldCompileAndRun("main.d", "foo.d");
    }
}
