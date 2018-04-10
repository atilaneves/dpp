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

@("POD struct private then public")
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
                static assert(__traits(getProtection, f.i) == "private");
                static assert(__traits(getProtection, f.d) == "public");
                f.d = 22.2;
            }
        ),
   );
}


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
                static assert(__traits(getProtection, f.i) == "private");
                static assert(__traits(getProtection, f.d) == "private");
            }
        ),
   );
}

@("POD class public then private")
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
                static assert(__traits(getProtection, f.i) == "public");
                static assert(__traits(getProtection, f.d) == "private");
                f.i = 7; // public, ok
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
