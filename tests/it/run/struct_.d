module it.run.struct_;

import it.run;

@("structs")
@safe unittest {
    with(const IncludeSandbox()) {

        expand(Out("foo.d"), In("foo.h"),
               q{
                   struct Foo { int i; };

                   struct Bar { double d; };

                   struct Outer {
                       struct Inner {
                           int x;
                       } inner;
                   };

                   typedef struct TypeDefd_ {
                       int i;
                       double d;
                   } TypeDefd;

                   typedef struct {
                       int x, y;
                   } Nameless1;

                   typedef struct {
                       double d;
                   } Nameless2;
               }
        );

        writeFile("main.d", q{
            import foo;

            void main() {

                auto f = struct_Foo(5);
                assert(f.sizeof == 4, "Wrong sizeof for Foo");
                assert(f.i == 5, "f.i should be 5");

                auto b = struct_Bar(33.3);
                assert(b.sizeof == 8, "Wrong sizeof for Foo");
                assert(b.d == 33.3, "b.d should be 33.3");

                auto o = struct_Outer(struct_Outer.struct_Inner(42));
                assert(o.sizeof == 4, "Wrong sizeof for Outer");
                assert(o.inner.x == 42, "o.innter.x should be 42");

                {
                    auto t = struct_TypeDefd_(42, 33.3);
                    assert(t.sizeof == 16, "Wrong sizeof for TypeDefd_");
                    assert(t.i == 42, "t.i should be 42");
                    assert(t.d == 33.3, "t.d should be 33.3");
                }
                {
                    auto t = TypeDefd(42, 33.3);
                    assert(t.sizeof == 16, "Wrong sizeof for TypeDefd");
                    assert(t.i == 42, "t.i should be 42");
                    assert(t.d == 33.3, "t.d should be 33.3");
                }

                auto n1 = Nameless1(2, 3);
                assert(n1.sizeof == 8, "Wrong sizeof for Nameless1");
                assert(n1.x == 2, "n1.x should be 2");
                assert(n1.y == 3, "n1.y should be 3");

                auto n2 = Nameless2(33.3);
                assert(n2.sizeof == 8, "Wrong sizeof for Nameless2");
                assert(n2.d == 33.3, "n2.d should be 33.3");
            }
        });

        shouldCompileAndRun("main.d", "foo.d");
    }
}
