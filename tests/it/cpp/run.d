/**
   C++ tests that must run
 */
module it.cpp.run;

import it;

@Tags("run")
@("function")
@safe unittest {
    shouldCompileAndRun(
        Cpp(
            q{
                int add(int i, int j);
            }
        ),
        Cpp(
            q{
                int add(int i, int j) { return i + j; }
            }
        ),
        D(
            q{
                import std.exception: assertThrown;
                import core.exception: AssertError;
                assert(add(2, 3) == 5, "add(2, 3) should be 5");
                void func() {
                    assert(add(2, 3) == 7);
                }
                assertThrown!AssertError(func(), "add(2, 3) should not be 7");
            }
         ),
    );
}

@Tags("run", "collision")
@("collisions")
@safe unittest {
    shouldRun(
        Cpp(
            q{
                struct foo {
                    int i;
                };
                int foo(int i, int j);
                struct foo add_foo_ptrs(const struct foo* f1, const struct foo* f2);

                union bar {
                    int i;
                    double d;
                };
                int bar(int i);

                enum baz { one, two, three };
                int baz();

                enum other { four, five };
                int other;
            }
        ),
        Cpp(
            q{
                int foo(int i, int j) { return i + j + 1; }
                struct foo add_foo_ptrs(const struct foo* f1, const struct foo* f2) {
                    struct foo ret;
                    ret.i = f1->i + f2->i;
                    return ret;
                }
                int bar(int i) { return i * 2; }
                int baz() { return 42; }
            }
        ),
        D(
            q{
                assert(foo_(2, 3) == 6);
                assert(bar_(4) == 8);
                assert(baz_ == 42);

                auto f1 = foo(2);
                auto f2 = foo(3);
                assert(add_foo_ptrs(&f1, &f2) == foo(5));

                bar b;
                b.i = 42;
                b.d = 33.3;

                baz z1 = two;
                baz z2 = baz.one;

                other_ = 77;
                other o1 = other.four;
                other o2 = five;

                import std.exception: assertThrown;
                import core.exception: AssertError;
                void func() {
                    assert(foo_(2, 3) == 7);
                }
                assertThrown!AssertError(func());
            }
         ),
    );

}
