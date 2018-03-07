module it.translation.struct_;

import it.translation;

@("int called i")
@safe unittest {
    with(const TranslationSandbox()) {

        expand(Out("foo.d"), In("foo.h"), [q{struct Foo { int i; };}]);

        writeFile("main.d", q{
            import foo;
            void main() {
                auto f = Foo(5);
                assert(f.sizeof == 4, "Wrong sizeof for Foo");
                assert(f.i == 5, "f.i should be 5");
            }
        });

        shouldCompileAndRun("main.d", "foo.d");
    }
}

@("int called x")
@safe unittest {
    with(const TranslationSandbox()) {

        expand(Out("foo.d"), In("foo.h"), [q{struct Foo { int x; };}]);

        writeFile("main.d", q{
            import foo;
            void main() {
                auto f = Foo(5);
                assert(f.sizeof == 4, "Wrong sizeof for Foo");
                assert(f.x == 5, "f.i should be 5");
            }
        });

        shouldCompileAndRun("main.d", "foo.d");
    }
}

@("double called d")
@safe unittest {
    with(const TranslationSandbox()) {

        expand(Out("foo.d"), In("foo.h"), [q{struct Foo { double d; };}]);

        writeFile("main.d", q{
            import foo;
            void main() {
                auto f = Foo(33.3);
                assert(f.sizeof == 8, "Wrong sizeof for Foo");
                assert(f.d == 33.3, "f.i should be 33.3");
            }
        });

        shouldCompileAndRun("main.d", "foo.d");
    }
}
