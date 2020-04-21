/**
   Non-standard language extensions
 */
module it.c.compile.extensions;


import it;


@("typeof")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Foo;
                // typeof is a gcc and clang language extension
                typeof(struct Foo *) func();
            }
        ),

        D(
            q{
                import std.traits: ReturnType;
                static assert(is(ReturnType!func == Foo*));
            }
        ),
    );
}

@("Type cast with typeof")
@safe unittest {
    shouldCompile(
        C(
            `
                #define DUMMY(x) (sizeof((typeof(x) *)1))
            `
        ),

        D(
            q{
                auto a = DUMMY(7);
            }
        ),
    );
}
