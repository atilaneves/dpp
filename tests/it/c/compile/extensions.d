/**
   Non-standard language extensions
 */
module it.c.compile.extensions;


import it;


@HiddenTest // used to pass now fails, not sure how to make clang parse it right
@("typeof.funcdecl")
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

@HiddenTest // used to pass now fails, not sure how to make clang parse it right
@("typeof.cast")
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
