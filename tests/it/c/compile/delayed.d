/**
   Tests for declarations that must be done at the end when they
   haven't appeared yet (due to pointers to undeclared structs)
 */
module it.c.compile.delayed;

import it;

@("field of unknown struct pointer")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct Foo {
                    struct Bar* bar;
                } Foo;
            }
        ),
        D(
            q{
                Foo f;
                f.bar = null;
            }
        ),
    );
}


@("unknown struct pointer return")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Foo* fun(int);
            }
        ),
        D(
            q{
                auto f = fun(42);
                static assert(is(typeof(f) == Foo*));
            }
        ),
    );
}

@ShouldFail
@("unknown struct pointer param")
@safe unittest {
    shouldCompile(
        C(
            q{
                int fun(struct Foo* foo);
            }
        ),
        D(
            q{
                Foo* foo;
                int i = fun(foo);
            }
        ),
    );
}

@ShouldFail("issue24")
@Tags("issue")
@("unknown struct pointer field and function")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Foo { struct cancel* the_cancel; };
                void cancel(int);
            }
        ),
        D(
            q{
            }
        ),
    );
}
