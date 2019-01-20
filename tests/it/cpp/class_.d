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
                static assert(is(typeof(Derived._base1.d) == double));
            }
        ),
   );
}


@("hard_to_describe")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Member {
                    // having a constructor caused dpp to emit a `@disable this`
                    Member(const char*);
                };

                template <typename T>
                struct Template {
                    T payload;
                };

                struct Struct {
                    Member member;
                    static Template<Struct> global;
                };
            }
        ),
        D(
            q{
                // just to check that the D code compiles
            }
        ),
   );
}


@("rule_of_5")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Struct {
                    Struct(Struct&&) = default;
                    Struct& operator=(Struct&&) = default;
                    Struct& operator=(const Struct&) = default;
                };
            }
        ),
        D(
            q{
                // just to check that the D code compiles
            }
        ),
   );
}
