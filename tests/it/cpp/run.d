/**
   C++ tests that must run
 */
module it.cpp.run;

import it;

@Tags("run")
@("ctor")
@safe unittest {
    shouldCompileAndRun(
        Cpp(
            q{
                struct Struct {
                    void *data;

                    Struct(int i);
                    Struct(const Struct&);
                    Struct(Struct&&);

                    int number() const;
                };
            }
        ),
        Cpp(
            `
                #include <iostream>
                using namespace std;
                Struct::Struct(int i) {
                    cout << "C++: int ctor" << endl;
                    data = new int(i);
                }
                Struct::Struct(const Struct& other) {
                    cout << "C++: copy ctor" << endl;
                    data = new int(*reinterpret_cast<int*>(other.data));
                }
                Struct::Struct(Struct&& other) {
                    cout << "C++: move ctor" << endl;
                    data = new int(*reinterpret_cast<int*>(other.data));
                }
                int Struct::number() const { return *reinterpret_cast<int*>(data); }
            `
        ),
        D(
            q{
                import std.stdio;

                writeln("D: Testing int ctor");
                auto s1 = const Struct(42);
                assert(s1.number() == 42);
                assert(*(cast(int*)s1.data) == 42);

                writeln("D: Testing copy ctor");
                auto s2 = Struct(s1);
                assert(s2.number() == 42);
                assert(s1.data !is s2.data);

                writeln("D: Testing move ctor");
                auto tmp = Struct(33);
                auto s3 = Struct(dpp.move(tmp));
                assert(s3.number() == 33);
            }
         ),
    );
}


@Tags("run")
@("dtor")
@safe unittest {
    shouldCompileAndRun(
        Cpp(
            q{
                struct Struct {
                    static int numStructs;
                    Struct(int i);
                    ~Struct();
                };
            }
        ),
        Cpp(
            q{
                int Struct::numStructs;
                // the i parameter is to force D to call a constructor,
                // since Struct() just blasts it with Struct.init
                Struct::Struct(int i)  { numStructs += i; }
                Struct::~Struct()      { --numStructs; }
            }
        ),
        D(
            q{
                import std.conv: text;
                assert(Struct.numStructs == 0, Struct.numStructs.text);
                {
                    auto s1 = Struct(3);
                    assert(Struct.numStructs == 3, Struct.numStructs.text);

                    {
                        auto s2 = Struct(2);
                        assert(Struct.numStructs == 5, Struct.numStructs.text);
                    }

                    assert(Struct.numStructs == 4, Struct.numStructs.text);
                }

                assert(Struct.numStructs == 3, Struct.numStructs.text);
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


@ShouldFail("dmd can't mangle operators even with pragma(mangle)")
@Tags("run")
@("operators")
@safe unittest {
    shouldRun(
        Cpp(
            q{
                struct Struct {
                    int i;
                    Struct(int i);
                    Struct operator+(const Struct& other);
                };
            }
        ),
        Cpp(
            q{
                Struct::Struct(int i):i{i} {}
                Struct Struct::operator+(const Struct& other) { return { i + other.i }; }
            }
        ),
        D(
            q{
                auto s2 = Struct(2);
                auto s3 = Struct(3);
                assert(s2 + s3 == Struct(5));
            }
         ),
    );

}
