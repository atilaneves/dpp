module it.cpp.templates;


import it;


@("simple")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename T>
                struct vector {
                public:
                    T value;
                    void push_back();
                };

                template<typename U, int length>
                struct array {
                public:
                    U elements[length];
                };

            }
        ),
        D(
            q{
                auto vi = vector!int(42);
                static assert(is(typeof(vi.value) == int));
                vi.value = 33;

                auto vf = vector!float(33.3);
                static assert(is(typeof(vf.value) == float));
                vf.value = 22.2;

                auto vs = vector!string("foo");
                static assert(is(typeof(vs.value) == string));
                vs.value = "bar";

                auto ai = array!(int, 3)();
                static assert(ai.elements.length == 3);
                static assert(is(typeof(ai.elements[0]) == int));
            }
        ),
   );
}

@("nameless type")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                // none of the template parameters have names, which is allowed
                // in C++ but not in D
                template<bool, bool, typename>
                struct Foo {

                };
            }
        ),
        D(
            q{
                auto f = Foo!(true, false, int)();
            }
        ),
    );
}

@("struct full specialisation")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                // this is a ClassTemplate
                template<bool, bool, typename>
                struct __copy_move {
                    enum { value = 42 };
                };

                // This is a StructDecl
                template<>
                struct __copy_move<false, true, double> {
                    enum { value = 33 };
                };
            }
        ),
        D(
            q{
                import std.conv: text;

                // FIXME: libclang bug - templates don't have proper
                // EnumConstantDecl values for some reason
                // auto c1 = __copy_move!(true, true, int)();
                // static assert(c1.value == 42, text(cast(int) c1.value));

                auto c2 = __copy_move!(false, true, double)();
                static assert(c2.value == 33, text(cast(int) c2.value));
            }
        ),
    );
}

// struct/class keyword could end up in different code paths
@("class full specialisation")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                // this is a ClassTemplate
                template<bool, bool, typename>
                class __copy_move {
                public:
                    enum { value = 42 };
                };

                // This is a ClassDecl
                template<>
                class __copy_move<false, true, double> {
                public:
                    enum { value = 33 };
                };
            }
        ),
        D(
            q{
                import std.conv: text;

                // FIXME: libclang bug - templates don't have proper
                // EnumConstantDecl values for some reason
                // auto c1 = __copy_move!(true, true, int)();
                // static assert(c1.value == 42, text(cast(int) c1.value));

                auto c2 = __copy_move!(false, true, double)();
                static assert(c2.value == 33, text(cast(int) c2.value));
            }
        ),
    );
}

@("struct partial specialisation")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                // just structs to use as template type parameters
                struct Foo; struct Bar; struct Baz; struct Quux;

                // this is a ClassTemplate
                template<typename, typename, bool, typename, int, typename>
                struct Template { using Type = bool; };

                // this is a ClassTemplatePartialSpecialization
                template<typename T, bool V0, typename T3, typename T4>
                struct Template<Quux, T, V0, T3, 42, T4> { using Type = short; };

                // this is a ClassTemplatePartialSpecialization
                template<typename T, bool V0, typename T3, typename T4>
                struct Template<T, Quux, V0, T3, 42, T4> { using Type = double; };
            }
        ),
        D(
            q{
                import std.conv: text;

                auto t1 = Template!(Foo,  Bar,  false, Baz,  0, Quux)(); // full template
                auto t2 = Template!(Quux, Bar,  false, Baz, 42, Quux)(); // partial1
                auto t3 = Template!(Foo,  Quux, false, Baz, 42, Quux)(); // partial2

                static assert(is(t1.Type == bool),   t2.Type.stringof);
                static assert(is(t2.Type == short),  t2.Type.stringof);
                static assert(is(t3.Type == double), t3.Type.stringof);
            }
        ),
    );
}



// as seen in stl_algobase.h
@("__copy_move")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace std {
                    struct random_access_iterator_tag;

                    template<bool, bool, typename>
                    struct copy_move {};

                    template<typename _Category>
                    struct copy_move<true, false, _Category> {};

                    template<>
                    struct copy_move<false, false, random_access_iterator_tag> {};

                    template<>
                    struct copy_move<true, false, random_access_iterator_tag> {};

                    template<bool _IsMove>
                    struct copy_move<_IsMove, true, random_access_iterator_tag> {};
                }
            }
        ),
        D(
            q{
                struct RandomStruct {}
                auto c1 = copy_move!(false, true, int)();
                auto c2 = copy_move!(true, false, RandomStruct)();
                auto c3 = copy_move!(false, false, random_access_iterator_tag)();
                auto c4 = copy_move!(true, false, random_access_iterator_tag)();
                auto c5 = copy_move!(false, true, random_access_iterator_tag)();
                auto c6 = copy_move!(true, true, random_access_iterator_tag)();
            }
        ),
    );
}


@("constexpr struct variable")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename _Tp, _Tp __v>
                struct integral_constant {
                    public: // FIXME #76
                    static constexpr _Tp value = __v;
                };
            }
        ),
        D(
            q{
                static assert(integral_constant!(int, 42).value == 42);
                static assert(integral_constant!(int, 33).value == 33);
            }
        ),
    );
}

@("typedef to template type parameter")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename _Tp, _Tp __v>
                struct integral_constant {
                    public: // FIXME #76
                    typedef _Tp value_type;
                };
            }
        ),
        D(
            q{
                static assert(is(integral_constant!(short, 42).value_type == short));
                static assert(is(integral_constant!(long, 42).value_type == long));
            }
        ),
    );
}

@("typedef to template struct")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename _Tp, _Tp __v>
                struct integral_constant {
                    public: // FIXME #76
                    typedef integral_constant<_Tp, __v>   type;
                };
            }
        ),
        D(
            q{
                static assert(is(integral_constant!(int, 33).type == integral_constant!(int, 33)));
            }
        ),
    );
}

@("opCast template type")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename _Tp, _Tp __v>
                struct integral_constant
                {
                    public: // FIXME #76
                    static constexpr _Tp value = __v;
                    typedef _Tp value_type;
                    constexpr operator value_type() const noexcept { return value; }
                };
            }
        ),
        D(
            q{
                integral_constant!(int , 42) i;
                auto j = cast(int) i;
            }
        ),
    );
}


// as seen in type_traits
@("integral_constant")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename _Tp, _Tp __v>
                struct integral_constant
                {
                    public: // FIXME #76
                    static constexpr _Tp value = __v;
                    typedef _Tp value_type;
                    constexpr operator value_type() const noexcept { return value; }
                    constexpr value_type operator()() const noexcept { return value; }
                };
            }
        ),
        D(
            q{
            }
        ),
    );
}


@("variadic.base.types")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<int, typename, bool, typename...>
                struct VariadicTypes {
                    using Type = void;
                };
            }
        ),
        D(
            q{
                static assert(is(VariadicTypes!(0, short, false).Type == void));
                static assert(is(VariadicTypes!(1, short, false, int).Type == void));
                static assert(is(VariadicTypes!(2, short, false, int, double, bool).Type == void));
                static assert(is(VariadicTypes!(3, short, false, int, int).Type == void));
            }
        ),
    );
}

@("variadic.base.values")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<short, typename, bool, int...>
                struct VariadicValues {
                    using Type = void;
                };
            }
        ),
        D(
            q{
                static assert(is(VariadicValues!(0, float, false).Type == void));
                static assert(is(VariadicValues!(1, float, false, 0, 1, 2, 3).Type == void));
            }
        ),
    );
}


@("variadic.specialized")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename...>
                struct Variadic {
                    using Type = void;
                };

                template<typename T0, typename T1>
                struct Variadic<T0, T1> {
                    using Type = bool;
                };
            }
        ),
        D(
            q{
                static assert(is(Variadic!().Type == void)); // general
                static assert(is(Variadic!(int).Type == void)); // general
                static assert(is(Variadic!(int, double, bool).Type == void)); // general
                static assert(is(Variadic!(int, int).Type == bool)); // specialisation
            }
        ),
    );
}


// as seen in type_traits
@("__or_")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename _Tp, _Tp __v>
                struct integral_constant
                {
                    static constexpr _Tp                  value = __v;
                    typedef _Tp                           value_type;
                    typedef integral_constant<_Tp, __v>   type;
                    constexpr operator value_type() const noexcept { return value; }
                    constexpr value_type operator()() const noexcept { return value; }
                };

                template<typename _Tp, _Tp __v>
                constexpr _Tp integral_constant<_Tp, __v>::value;

                typedef integral_constant<bool, true>     true_type;

                typedef integral_constant<bool, false>    false_type;

                template<bool, typename, typename>
                struct conditional;

                template<typename...>
                struct __or_;

                template<>
                struct __or_<> : public false_type { };

                template<typename _B1>
                struct __or_<_B1> : public _B1 { };

                template<typename _B1, typename _B2>
                struct __or_<_B1, _B2>
                    : public conditional<_B1::value, _B1, _B2>::type
                { };

                template<typename _B1, typename _B2, typename _B3, typename... _Bn>
                struct __or_<_B1, _B2, _B3, _Bn...>
                    : public conditional<_B1::value, _B1, __or_<_B2, _B3, _Bn...>>::type
                { };

                template<bool _Cond, typename _Iftrue, typename _Iffalse>
                struct conditional
                { typedef _Iftrue type; };

                template<typename _Iftrue, typename _Iffalse>
                struct conditional<false, _Iftrue, _Iffalse>
                { typedef _Iffalse type; };
            }
        ),
        D(
            q{
                // TODO: actually assert on the types
            }
        ),
    );
}


@("__or_.binary")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <typename...> struct __or_;
                template <typename B0, typename B1>
                struct __or_<B0, B1> {
                    static constexpr auto value = true;
                };

                template <typename T>
                struct is_copy_constructible {
                    static constexpr auto value = true;
                };

                template <typename T>
                struct is_nothrow_move_constructible {
                    static constexpr auto value = true;
                };

                template <typename T, bool B
                    = __or_<is_copy_constructible<typename T::value_type>,
                    is_nothrow_move_constructible<typename T::value_type>>::value>
                struct Oops {
                    static constexpr auto value = B;
                };
            }
        ),
        D(
            q{
                struct Foo {
                    alias value_type = int;
                }
                static assert(Oops!Foo.value);
            }
        ),
    );
}


// as seen in type traits
@("is_lvalue_reference")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename _Tp, _Tp __v>
                struct integral_constant
                {
                    static constexpr _Tp                  value = __v;
                    typedef _Tp                           value_type;
                    typedef integral_constant<_Tp, __v>   type;
                    constexpr operator value_type() const noexcept { return value; }
                    constexpr value_type operator()() const noexcept { return value; }
                };

                template<typename _Tp, _Tp __v>
                constexpr _Tp integral_constant<_Tp, __v>::value;

                typedef integral_constant<bool, true>  true_type;
                typedef integral_constant<bool, false> false_type;

                template<typename>
                struct is_lvalue_reference: public false_type { };

                template<typename _Tp>
                struct is_lvalue_reference<_Tp&>: public true_type { };
            }
        ),
        D(
            q{
                // FIXME #85
                // static assert(!is_lvalue_reference!int.value);
                // static assert( is_lvalue_reference!(int*).value);
            }
        ),
    );
}


// as seen in type traits
@("decltype")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename T>
                struct Struct {
                    T i;
                    using Type = decltype(i);
                };
            }
        ),
        D(
            q{
                static assert(is(Struct!int.Type == int));
                static assert(is(Struct!double.Type == double));
            }
        ),
    );
}


// as seen in type traits
@("typename")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename T>
                struct TheType {
                    using Type = T;
                };

                template<typename T>
                struct Struct {
                    using AlsoType = typename TheType<T>::Type;
                };
            }
        ),
        D(
            q{
                static assert(is(Struct!int.AlsoType == int));
                static assert(is(Struct!double.AlsoType == double));
            }
        ),
    );
}


// as seen in type traits
@("add_volatile")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename T>
                struct add_volatile { using Type = volatile T; };
            }
        ),
        D(
            q{
                static assert(is(add_volatile!int.Type == int));
                static assert(is(add_volatile!double.Type == double));
            }
        ),
    );
}


// as seen in type traits
@("unsigned")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<bool C, typename T0, typename T1>
                struct Helper {
                    using Type = T1;
                };

                template<typename T>
                struct Thingie {
                    static const bool b0 = sizeof(T) < sizeof(unsigned short);
                    using Type = typename Helper<b0, unsigned long, unsigned long long>::Type;
                };
            }
        ),
        D(
            q{
            }
        ),
    );
}


@("sizeof")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename T>
                struct Thingie {
                    static constexpr auto b0 = sizeof(T) < sizeof(unsigned short);
                };
            }
        ),
        D(
            q{
                static assert( Thingie!ubyte.b0);
                static assert(!Thingie!int.b0);
            }
        ),
    );
}



@("__normal_iterator.base")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename I>
                struct Struct {
                    I i;
                    const I& base() const { return i; }
                };
            }
        ),
        D(
            q{
                struct Int { int value; }
                Struct!Int s;
                Int i = s.base();
            }
        ),
   );
}


@ShouldFail("need to fix declaration of new template parameters in specialisations")
@("move_iterator.reference")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<bool _Cond, typename _Iftrue, typename _Iffalse>
                struct conditional
                { typedef _Iftrue type; };

                template<typename _Iftrue, typename _Iffalse>
                struct conditional<false, _Iftrue, _Iffalse>
                { typedef _Iffalse type; };

                template<typename T> struct remove_reference      { using type = T; };
                template<typename T> struct remove_reference<T&>  { using type = T; };
                template<typename T> struct remove_reference<T&&> { using type = T; };

                template<typename T> struct is_reference      { enum { value = false }; };
                template<typename T> struct is_reference<T&>  { enum { value = true  }; };
                template<typename T> struct is_reference<T&&> { enum { value = true  }; };

                template<typename T>
                struct Iterator {
                    using reference = typename conditional<is_reference<T>::value,
                                                           typename remove_reference<T>::type&&,
                                                           T>::type;
                };
            }
        ),
        D(
            q{
            }
        ),
   );
}


@("allocator.simple")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <typename> class allocator;
                template <> class allocator<void>;
                template <> class allocator<void> {
                    template<typename Up, typename... Args>
                    void construct(Up* p, Args&&... args);
                };
            }
        ),
        D(
            q{
                auto a = allocator!void();
                static struct Foo { int i; double d; }
                Foo* foo;
                a.construct(foo, 42, 33.3);
            }
        ),
   );
}

@("allocator.pointer")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <typename T>
                class Allocator {
                    typedef T* pointer;
                };
            }
        ),
        D(
            q{
                static assert(is(Allocator!int.pointer == int*));
                static assert(is(Allocator!double.pointer == double*));
            }
        ),
   );
}


@("refer to type template argument in another argument")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename T, int S = sizeof(T)>
                struct Foo {
                    static constexpr auto Size = S;
                };
            }
        ),
        D(
            q{
                static assert(Foo!int.Size == 4);
                static assert(Foo!long.Size == 8);
            }
        ),
    );
}


@("__is_empty.specialisation")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename T, bool = __is_empty(T)>
                struct Foo {
                    static constexpr auto value = 1;
                };

                template<typename T>
                struct Foo<T, false> {
                    static constexpr auto value = 2;
                };
            }
        ),
        D(
            q{
                struct Empty{}
                struct Int { int i; }

                static assert(Foo!Empty.value == 1);
                // In C++ the assertion below would pass. In D it doesn't
                // due to different semantics, but explicitly picking the
                // specialisation works.
                // static assert(Foo!Int.value == 2);
                static assert(Foo!(Int, false).value == 2);
            }
        ),
   );
}



@("default template type parameter")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <typename T>
                struct Allocator {
                };

                template <typename T, typename A = Allocator<T>>
                struct Vector {

                };
            }
        ),
        D(
            q{
                Vector!int ints;
            }
        ),
   );
}

@("specialisation for cv")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <typename T>
                struct Allocator {
                    using Type = void;
                    enum { value = 0 };
                };

                template <typename T>
                struct Allocator<const T> {
                    using Type = short;
                };

                template <typename T>
                struct Allocator<volatile T> {
                    using Type = float;
                };
            }
        ),
        D(
            q{
                // we can't specialise on const
                static assert(is(Allocator!int.Type == void), Allocator!int.Type.stringof);
                static assert(is(Allocator!(const int).Type == void), Allocator!(const int).Type.stringof);
            }
        ),
   );
}


@("declaration and definitions with different template argument names")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace std {
                    template <typename> class allocator;
                }

                namespace std {
                    template <typename T> class allocator {
                    public:
                        static constexpr auto value = 42;
                        allocator(const allocator& other) throw() {}
                    };
                }
            }
        ),
        D(
            q{
                allocator!int foo = void;
                static assert(foo.value == 42);
            }
        ),
   );
}


@("using.partial")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename T>
                    struct new_allocator {
                };

                template<typename _Tp>
                using __allocator_base = new_allocator<_Tp>;
            }
        ),
        D(
            q{
                static assert(is(__allocator_base!int == new_allocator!int));
            }
        ),
   );
}


@("using.complete")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                /// A metafunction that always yields void, used for detecting valid types.
                template<typename...> using void_t = void;
            }
        ),
        D(
            q{
                static assert(is(void_t!int == void), void_t!int.stringof);
            }
        ),
   );
}


@("function.equals")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo {
                    template<typename T0, typename T1>
                    bool equals(T0 lhs, T1 rhs);
                };
            }
        ),
        D(
            q{
                Foo foo0, foo1;
                bool res = foo0.equals(foo0, foo1);
            }
        ),
   );
}


@("function.ctor")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <typename T>
                struct Foo {
                    template<typename U>
                    Foo(const Foo<U>&);
                };
            }
        ),
        D(
            q{
                Foo!int fooInt;
                auto fooDouble = Foo!double(fooInt);
            }
        ),
   );
}


@("function.body.delete")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <typename T>
                struct Allocator {
                    void deallocate(T* ptr) {
                        ::operator delete(ptr);
                    }
                };
            }
        ),
        D(
            q{
                auto allocator = Allocator!int();
                allocator.deallocate(new int);
            }
        ),
   );
}



@("ns.out.longname")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace DasNamespace {
                    template<typename Idx>
                    struct Foo {
                        using Instant = typename Idx::Instant;
                        const Instant& instant() const;
                    };

                    template<typename Idx>
                    const typename Foo<Idx>::Instant& Foo<Idx>::instant() const {
                        throw 42;
                    }
                }
            }
        ),
        D(
            q{

            }
        ),
    );
}


@("ns.out.shortname")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                // namespace `ns` has letters that are in the middle of
                // `Instant` for potentially hilarious results
                namespace ns {
                    template<typename Idx>
                    struct Foo {
                        using Instant = typename Idx::Instant;
                        const Instant& instant() const;
                    };

                    template<typename Idx>
                    const typename Foo<Idx>::Instant& Foo<Idx>::instant() const {
                        throw 42;
                    }
                }
            }
        ),
        D(
            q{

            }
        ),
    );
}
