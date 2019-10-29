module it.c.compile.typeof_;


import it;


@("typeof with actual types")
@C(
    q{
        struct Foo;
        typeof(struct Foo *) f();
    }
)
@safe unittest {
    mixin(
        shouldCompile(
            D(
                q{
                }
            )
        )
    );
}

