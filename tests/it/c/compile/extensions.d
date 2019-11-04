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
