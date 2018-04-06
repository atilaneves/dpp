module it.cpp.class_;

import it;

@("POD struct")
unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo { int i; double d; };
            }
        ),
        D(
            q{
                auto f = Foo(42, 33.3);
                static assert(is(Foo == struct), "Foo should be a struct");
                f.i = 7;
                f.d = 3.14;
            }
        ),
   );
}

@ShouldFail
@("POD struct explicit privacy tags")
unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo {
                private:
                    int i;
                public:
                    double d;
                };
            }
        ),
        D(
            q{
                auto f = Foo(42, 33.3);
                static assert(is(Foo == struct), "Foo should be a struct");
                static assert(!__traits(compiles, f.i = 7), "f.i should be private");
                f.d = 3.14;
            }
        ),
   );
}


@ShouldFail("doesn't deal with public/private/etc")
@("POD class")
unittest {
    shouldCompile(
        Cpp(
            q{
                class Foo { int i; double d; };
            }
        ),
        D(
            q{
                auto f = Foo(42, 33.3);
                static assert(is(Foo == struct), "Foo should be a struct");
                static assert(!__traits(compiles, f.i = 7), "f.i should be private");
                static assert(!__traits(compiles, f.d = 3.14), "f.d should be private");
            }
        ),
   );
}

@ShouldFail
@("POD class explicit privacy tags")
unittest {
    shouldCompile(
        Cpp(
            q{
                class Foo {
                public:
                    int i;
                private:
                    double d;
                };
            }
        ),
        D(
            q{
                auto f = Foo(42, 33.3);
                static assert(is(Foo == struct), "Foo should be a struct");
                f.i = 7; // public, ok
                static assert(!__traits(compiles, f.d = 3.14), "f.d should be private");
            }
        ),
   );
}


@ShouldFail("Should throw on CXXMethod but instead the member gets ignored")
@("struct method")
unittest {
    shouldCompile(
        Cpp(
            q{
                struct Adder {
                    int add(int i, int j);
                };
            }
        ),
        D(
            q{
                static assert(is(Adder == struct), "Adder should be a struct");
                auto adder = Adder();
                int i = adder.add(2, 3);
            }
        ),
   );
}
