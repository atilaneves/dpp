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


@Tags("run")
@("operators")
@safe unittest {
    shouldRun(
        Cpp(
            q{
                struct Struct {
                    int i;
                    Struct(int i);

                    // Unary operators
                    Struct operator+ ()    const;
                    Struct operator- ()    const;
                    Struct operator* ()    const;
                    Struct operator& ()    const;
                    Struct operator->()    const;
                    Struct operator~ ()    const;
                    Struct operator! ()    const;
                    Struct operator++()    const;
                    Struct operator--()    const;
                    Struct operator++(int) const; // not defined on purpose
                    Struct operator--(int) const; // not defined on purpose

                    // Binary operators
                    Struct operator+  (const Struct& other) const;
                    Struct operator-  (const Struct& other) const;
                    Struct operator*  (const Struct& other) const;
                    Struct operator/  (const Struct& other) const;
                    Struct operator%  (const Struct& other) const;
                    Struct operator^  (const Struct& other) const;
                    Struct operator&  (const Struct& other) const;
                    Struct operator|  (const Struct& other) const;
                    Struct operator>> (const Struct& other) const;
                    Struct operator<< (const Struct& other) const;
                    Struct operator&& (const Struct& other) const;
                    Struct operator|| (const Struct& other) const;
                    Struct operator->*(const Struct& other) const;
                    Struct operator,  (const Struct& other) const;

                    // assignment
                    void operator=  (const Struct& other);
                    void operator+= (int j);
                    void operator-= (int j);
                    void operator*= (int j);
                    void operator/= (int j);
                    void operator%= (int j);
                    void operator^= (int j);
                    void operator&= (int j);
                    void operator|= (int j);
                    void operator>>=(int j);
                    void operator<<=(int j);

                    // special
                    int operator()(int j) const;
                    int operator[](int j) const;
                };
            }
        ),
        Cpp(
            q{
                Struct::Struct(int i):i{i} {}
                Struct Struct::operator+ () const { return { +i };    }
                Struct Struct::operator- () const { return { -i };    }
                Struct Struct::operator* () const { return { i * 3 }; }
                Struct Struct::operator& () const { return { i / 4 }; }
                Struct Struct::operator->() const { return { i / 3 }; }
                Struct Struct::operator~ () const { return { i + 9 }; }
                Struct Struct::operator! () const { return { i - 8 }; }
                Struct Struct::operator++() const { return { i + 1 }; }
                Struct Struct::operator--() const { return { i - 1 }; }

                Struct Struct::operator+  (const Struct& other) const { return { i + other.i }; }
                Struct Struct::operator-  (const Struct& other) const { return { i - other.i }; }
                Struct Struct::operator*  (const Struct& other) const { return { i * other.i }; }
                Struct Struct::operator/  (const Struct& other) const { return { i / other.i }; }
                Struct Struct::operator%  (const Struct& other) const { return { i % other.i }; }
                Struct Struct::operator^  (const Struct& other) const { return { i + other.i + 2 }; }
                Struct Struct::operator&  (const Struct& other) const { return { i * other.i + 1 }; }
                Struct Struct::operator|  (const Struct& other) const { return { i + other.i + 1 }; }
                Struct Struct::operator<< (const Struct& other) const { return { i + other.i }; }
                Struct Struct::operator>> (const Struct& other) const { return { i - other.i }; }
                Struct Struct::operator&& (const Struct& other) const { return { i && other.i }; }
                Struct Struct::operator|| (const Struct& other) const { return { i || other.i }; }
                Struct Struct::operator->*(const Struct& other) const { return { i - other.i }; }
                Struct Struct::operator,  (const Struct& other) const { return { i - other.i - 1 }; }

                void Struct::operator= (const Struct& other)  { i = other.i + 10; };
                void Struct::operator+=(int j)                { i += j;           };
                void Struct::operator-=(int j)                { i -= j;           };
                void Struct::operator*=(int j)                { i *= j;           };
                void Struct::operator/=(int j)                { i /= j;           };
                void Struct::operator%=(int j)                { i %= j;           };
                void Struct::operator^=(int j)                { i ^= j;           };
                void Struct::operator&=(int j)                { i &= j;           };
                void Struct::operator|=(int j)                { i |= j;           };
                void Struct::operator>>=(int j)               { i >>= j;          };
                void Struct::operator<<=(int j)               { i <<= j;          };

                int Struct::operator()(int j) const { return i * j; }
                int Struct::operator[](int j) const { return i / j; }
            }
        ),
        D(
            q{
                import std.conv: text;

                // unary
                assert(+Struct(-4) == Struct(-4));
                assert(-Struct(4)  == Struct(-4));
                assert(-Struct(-5) == Struct(5));
                assert(*Struct(2) == Struct(6));
                assert(Struct(8).opCppAmpersand == Struct(2));
                assert(Struct(9).opCppArrow == Struct(3));
                assert(~Struct(7) == Struct(16));
                assert(Struct(9).opCppBang == Struct(1));

                assert(++Struct(2) == Struct(3));
                assert(--Struct(5) == Struct(4));

                // binary
                auto s0 = const Struct(0);
                auto s2 = const Struct(2);
                auto s3 = const Struct(3);

                assert(s2 + s3 == Struct(5));
                assert(s3 - s2 == Struct(1));
                assert(Struct(5) - s2 == Struct(3));
                assert(s2 * s3 == Struct(6));
                assert(Struct(11) / s3 == Struct(3)) ;

                assert(Struct(5) % s2 == Struct(1));
                assert(Struct(6) % s2 == Struct(0));

                assert((Struct(4) ^ s2) == Struct(8));
                assert((Struct(4) & s2) == Struct(9));
                assert((Struct(4) | s2) == Struct(7));

                assert(Struct(7) >> s2 == Struct(5));
                assert(Struct(3) << s3 == Struct(6));

                assert(Struct(5).opCppArrowStar(s2) == Struct(3));
                assert(Struct(5).opCppComma(s2) == Struct(2));

                // assignment
                {
                    auto s = Struct(5);
                    s = s2; assert(s == Struct(12));
                }

                {
                    auto s = Struct(2);
                    s += 3; assert(s == Struct(5));
                    s -= 2; assert(s == Struct(3));
                    s *= 2; assert(s == Struct(6));
                    s /= 3; assert(s == Struct(2));
                    s = s3;
                    s %= 2; assert(s == Struct(1));
                    s ^= 1; assert(s == Struct(0));
                    s &= 1; assert(s == Struct(0));
                    s |= 1; assert(s == Struct(1));
                    s.i = 8;
                    s >>= 2; assert(s == Struct(2));
                    s <<= 1; assert(s == Struct(4));
                }

                // special
                assert(Struct(2)(3) == 6);
                assert(Struct(7)[2] == 3);
            }
         ),
    );
}

@ShouldFail("mangling problems")
@Tags("run")
@("templates")
@safe unittest {
    shouldRun(
        Cpp(
            q{
                template<typename T>
                class vector {
                    T _values[10];
                    int _numValues = 0;

                public:
                    void push_back(T value) {
                        _values[_numValues++] = value;
                    }

                    int numValues() { return _numValues; }
                    T value(int i) { return _values[i]; }
                };
            }
        ),
        Cpp(
            `
                #if __clang__
                    [[clang::optnone]]
                #elif __GNUC__
                    __attribute__((optimize("O0")))
                #endif
                    __attribute((used, noinline))
                static void instantiate() {
                    vector<int> v;
                    v.push_back(42);
                    const auto _ = v.value(0);
                }
            `
        ),
        D(
            q{
                vector!int v;
                assert(v.numValues == 0);

                v.push_back(4);
                assert(v.numValues == 1);
                assert(v.value(0) == 4);

                v.push_back(2);
                assert(v.numValues == 2);
                assert(v.value(0) == 2);
            }
         ),
    );
}
