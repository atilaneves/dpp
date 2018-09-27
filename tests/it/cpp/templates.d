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

@("template nameless type")
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
                    struct __copy_move {};

                    template<typename _Category>
                    struct __copy_move<true, false, _Category> {};

                    template<>
                    struct __copy_move<false, false, random_access_iterator_tag> {};

                    template<>
                    struct __copy_move<true, false, random_access_iterator_tag> {};

                    template<bool _IsMove>
                    struct __copy_move<_IsMove, true, random_access_iterator_tag> {};
                }
            }
        ),
        D(
            q{
                struct RandomStruct {}
                auto c1 = __copy_move!(false, true, int)();
                auto c2 = __copy_move!(true, false, RandomStruct)();
                auto c3 = __copy_move!(false, false, random_access_iterator_tag)();
                auto c4 = __copy_move!(true, false, random_access_iterator_tag)();
                auto c5 = __copy_move!(false, true, random_access_iterator_tag)();
                auto c6 = __copy_move!(true, true, random_access_iterator_tag)();
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
