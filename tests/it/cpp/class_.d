module it.cpp.class_;

import it;

@("POD struct")
@safe unittest {
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
@safe unittest {
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
                static assert(is(Foo == struct), "Foo should be a struct");
                static assert(__traits(getProtection, __traits(getMember, Foo, "i")) == "private");
                static assert(__traits(getProtection, __traits(getMember, Foo, "d")) == "public");
                Foo f;
                f.d = 22.2;
            }
        ),
   );
}


@("POD class")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class Foo { int i; double d; };
            }
        ),
        D(
            q{
                static assert(is(Foo == struct), "Foo should be a struct");
                static assert(__traits(getProtection, __traits(getMember, Foo, "i")) == "private");
                static assert(__traits(getProtection, __traits(getMember, Foo, "d")) == "private");
            }
        ),
   );
}

@("POD class public then private")
@safe unittest {
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
                static assert(is(Foo == struct), "Foo should be a struct");
                static assert(__traits(getProtection, __traits(getMember, Foo, "i")) == "public");
                static assert(__traits(getProtection, __traits(getMember, Foo, "d")) == "private");
                Foo f;
                f.i = 7; // public, ok
            }
        ),
   );
}


@("struct method")
@safe unittest {
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

@("ctor")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Adder {
                    int i;
                    Adder(int i, int j);
                    int add(int j);
                };
            }
        ),
        D(
            q{
                static assert(is(Adder == struct), "Adder should be a struct");
                auto adder = Adder(1, 2);
                int i = adder.add(4);
            }
        ),
   );
}

@("const method")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Adder {
                    int i;
                    Adder(int i, int j);
                    int add(int j) const;
                };
            }
        ),
        D(
            q{
                static assert(is(Adder == struct), "Adder should be a struct");
                auto adder = const Adder(1, 2);
                int i = adder.add(4);
            }
        ),
   );
}


@("inheritance.struct.single")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Base {
                    int i;
                };

                struct Derived: public Base {
                    double d;
                };
            }
        ),
        D(
            q{
                static assert(is(typeof(Derived.i) == int));
                static assert(is(typeof(Derived.d) == double));
            }
        ),
   );
}


@ShouldFail
@("inheritance.struct.multiple")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Base0 {
                    int i;
                };

                struct Base1 {
                    double d;
                };

                struct Derived: public Base0, public Base1 {

                };
            }
        ),
        D(
            q{
                static assert(is(typeof(Derived.i) == int));
                static assert(is(typeof(Derived.d) == double));
            }
        ),
   );
}
