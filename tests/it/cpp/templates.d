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

@ShouldFail
@("struct partial specialisation")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                // just structs to use as template type parameters
                struct Foo; struct Bar; struct Baz;

                // this is a ClassTemplate
                template<int, typename, bool, typename>
                struct Template { enum { value = 1 }; };

                // this is a ClassTemplatePartialSpecialization
                template<int V0, typename T0, typename T1>
                struct Template<V0, T0, true, T1> { enum { value = 2 }; };

                // this is a ClassTemplatePartialSpecialization
                template<int V0, bool V1, typename T1>
                struct Template<V0, Foo, V1, T1> { enum { value = 3 }; };
            }
        ),
        D(
            q{
                import std.conv: text;

                auto t1 = __copy_move!(true, true, int);       // full template
                auto t2 = __copy_move!(true, false, double)(); // partial specialisation 1
                auto t3 = __copy_move!(false, false, Foo)();   // partial specialisation 2

                static assert(t2.value == 2, text(cast(int) t2.value));
                static assert(t3.value == 3, text(cast(int) t3.value));
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
