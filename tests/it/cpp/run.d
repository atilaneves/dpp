/**
   C++ tests that must run
 */
module it.cpp.run;

import it;

@Tags("run")
@("dtor")
@safe unittest {
    shouldCompileAndRun(
        Cpp(
            q{
                struct Struct {
                    Struct(int i);
                    ~Struct();
                };
                extern int numStructs;
            }
        ),
        Cpp(
            q{
                int numStructs;
                // the i parameter is to force D to call a constructor,
                // since Struct() just blasts it with Struct.init
                Struct::Struct(int i)  { numStructs += i; }
                Struct::~Struct()      { --numStructs; }
            }
        ),
        D(
            q{
                import std.conv: text;
                assert(numStructs == 0, numStructs.text);
                {
                    auto s1 = Struct(3);
                    assert(numStructs == 3, numStructs.text);

                    {
                        auto s2 = Struct(2);
                        assert(numStructs == 5, numStructs.text);
                    }

                    assert(numStructs == 4, numStructs.text);
                }

                assert(numStructs == 3, numStructs.text);
            }
         ),
    );
}


@Tags("run")
@("function")
@safe unittest {
    shouldCompileAndRun(
        Cpp(
            q{
                int add(int i, int j);

                struct Adder {
                    int i;
                    Adder(int i);
                    int add(int j);
                };
            }
        ),
        Cpp(
            q{
                int add(int i, int j) { return i + j; }
                Adder::Adder(int i):i(i + 10) {}
                int Adder::add(int j) { return i + j; }
            }
        ),
        D(
            q{
                import std.conv: text;
                import std.exception: assertThrown;
                import core.exception: AssertError;

                assert(add(2, 3) == 5, "add(2, 3) should be 5");

                void func() {
                    assert(add(2, 3) == 7);
                }
                assertThrown!AssertError(func(), "add(2, 3) should not be 7");

                auto adder = Adder(3);
                assert(adder.add(4) == 17, "Adder(3).add(4) should be 17 not " ~ text(adder.add(4)));
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
