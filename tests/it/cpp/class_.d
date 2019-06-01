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


@("inner.return.nons")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Struct {
                    template<typename V>
                    struct Inner {};
                };
                const Struct::Inner<int>& inners();
            }
        ),
        D(
            q{
                // just to check that the D code compiles
            }
        ),
   );
}


@("inner.return.ns.normal")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                // it's important to have two different namespaces
                namespace lens0 {
                    struct Struct {
                        template<typename V>
                        struct Inner {};
                    };
                }

                const lens0::Struct::Inner<int>& inners();
            }
        ),
        D(
            q{
                // just to check that the D code compiles
            }
        ),
   );
}


@("inner.return.ns.using")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                // it's important to have two different namespaces
                namespace lens0 {
                    struct Struct {
                        template<typename V>
                        struct Inner {};
                    };
                }

                namespace lens1 {
                    using namespace lens0;
                    const Struct::Inner<int>& inners();
                }
            }
        ),
        D(
            q{
                // just to check that the D code compiles
            }
        ),
   );
}


@("virtual.base")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class Class {
                public:
                    virtual void pureVirtualFunc() = 0;
                    virtual void virtualFunc();
                    void normalFunc();
                };
            }
        ),
        D(
            q{
                static assert(is(Class == class), "Class is not a class");
            }
        ),
    );
}


@("virtual.child.override.normal")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class Base {
                public:
                    virtual void pureVirtualFunc() = 0;
                    virtual void virtualFunc();
                    void normalFunc();
                };

                class Derived: public Base {
                public:
                    void pureVirtualFunc() override;
                };
            }
        ),
        D(
            q{
                static assert(is(Base == class), "Base is not a class");
                static assert(is(Derived == class), "Derived is not a class");
                static assert(is(Derived: Base), "Derived is not a child class of Base");

                auto d = new Derived;
                d.pureVirtualFunc;
            }
        ),
    );
}


@("virtual.child.override.final")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct A {
                    virtual bool has() const noexcept { return false; }
                };

                struct B: A {
                    void foo();
                };

                struct C: B {
                    bool has() const noexcept final { return  true; }
                };
            }
        ),
        D(
            q{
                auto c = new C();
                const bool res = c.has;
            }
        ),
    );
}


@("virtual.child.empty.normal")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class Base {
                public:
                    virtual void virtualFunc();
                    void normalFunc();
                };

                class Derived: public Base {
                public:

                };
            }
        ),
        D(
            q{
                static assert(is(Base == class), "Base is not a class");
                static assert(is(Derived == class), "Derived is not a class");
                static assert(is(Derived: Base), "Derived is not a child class of Base");

                auto d = new Derived;
                d.virtualFunc;
                d.normalFunc;
            }
        ),
    );
}


@("virtual.child.empty.template")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename T>
                class Base {
                public:
                    virtual void virtualFunc();
                    void normalFunc();
                };

                class Derived: public Base<int> {
                public:

                };
            }
        ),
        D(
            q{
                static assert(is(Derived == class), "Derived is not a class");
                static assert(is(Derived: Base!int), "Derived is not a child class of Base");

                auto d = new Derived;
                d.virtualFunc;
                d.normalFunc;
            }
        ),
    );
}



@("virtual.dtor")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class Class {
                public:
                    virtual ~Class();
                };
            }
        ),
        D(
            q{
                static assert(is(Class == class), "Class is not a class");
            }
        ),
    );
}


@("virtual.opAssign")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class Class {
                public:
                    virtual ~Class();
                    Class& operator=(const Class&);
                };
            }
        ),
        D(
            q{
                static assert(is(Class == class), "Class is not a class");
            }
        ),
    );
}


@("ctor.default")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class Base {
                public:
                    virtual ~Base();
                    Base() = default;
                    // the presence of the move ctor caused the compiler to fail with
                    // "cannot implicitly generate a default constructor"
                    // because the default ctor was ignored
                    Base(Base&&) = default;
                };

                class Derived: public Base {
                    virtual void func();
                };
            }
        ),
        D(
            q{
                static assert(is(Base == class), "Base is not a class");
                static assert(is(Derived == class), "Derived is not a class");
                static assert(is(Derived: Base), "Derived is not a child class of Base");
            }
        ),
    );
}


@("ctor.using")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class Base {
                public:
                    Base(int i);
                    Base(const Base&) = delete;
                    Base(Base&&) = delete;
                    virtual ~Base();
                };

                class Derived: public Base {
                    using Base::Base;
                };
            }
        ),
        D(
            q{
                static assert(is(Base == class), "Base is not a class");
                static assert(is(Derived == class), "Derived is not a class");
                static assert(is(Derived: Base), "Derived is not a child class of Base");

                auto d = new Derived(42);
            }
        ),
        ["--hard-fail"],
    );
}
