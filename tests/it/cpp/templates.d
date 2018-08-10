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
@ShouldFail
@("__copy_move")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
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
        ),
        D(
            q{
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
