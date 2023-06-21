module it.c.compile.preprocessor;


import it;


@("simple macro")
@safe unittest {
    shouldCompile(
        C(
            `
                #define FOO 5
            `
        ),
        D(
            q{
                int[FOO] foos;
                static assert(foos.length == 5, "Wrong length for foos");
            }
        )
    );
}

@("define macro, undefine, then define again")
@safe unittest {
    shouldCompile(
        C(
            `
                #define FOO foo
                #undef FOO
                #define FOO bar
                int FOO(int i);
            `
        ),
        D(
            q{
                int i = bar(2);
            }
        )
    );
}


@("include guards")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h",
                  `#ifndef HAHA
                   #    define HAHA
                   int inc(int);
                   #endif`);
        writeFile("foo.dpp",
                  `#include "hdr.h"
                   import bar;
                   int func(int i) { return inc(i) * 2; }`);
        writeFile("bar.dpp",
                  `#include "hdr.h";
                   int func(int i) { return inc(i) * 3; }`);

        runPreprocessOnly("foo.dpp");
        runPreprocessOnly("bar.dpp");
        shouldCompile("foo.d");
    }
}


@("octal.whitespace")
@safe unittest {
    shouldCompile(
        C(
            `
                #define FOO	   00
            `
        ),
        D(
            q{
            }
        )
    );

}


@("elaborate")
@safe unittest {
    shouldCompile(
        C(
            `
                struct Foo {};
                #define STRUCT_HEAD \
                    int count; \
                    struct Foo *foo;
            `
        ),
        D(
            q{
                static struct Derived {
                    STRUCT_HEAD
                }

                auto d = Derived();
                d.count = 42;
                d.foo = null;
            }
        )
    );
}


@("user-defined struct cast in macro")
@safe unittest {
    shouldCompile(
        C(
            `
                struct foo { int bar; };
                #define PTR(st, vr) ((struct st *) &vr)
                #define PTR_CONST1(st, vr) ((const struct st *) &vr)
                #define PTR_CONST2(st, vr) ((struct st const *) &vr)
                #define PTR_CONST3(st, vr) ((struct st * const) &vr)
            `
        ),
        D(
            q{
                foo f;
                auto a = PTR(foo, f);
                auto b = PTR_CONST1(foo, f);

                // DPP does not currently translate those "macro params"
                // i.e. leaves "struct foo const *" unchanged
                // auto c = PTR_CONST2(foo, f);
                // auto d = PTR_CONST3(foo, f);
            }
        )
    );
}


version(Posix)  // FIXME
@("multiline")
@safe unittest {
    shouldCompile(
        C(
            `
                // WARNING: don't attempt to tidy up the formatting here or the
                // test is actually changed
#define void_to_int_ptr(x) ( \
    (int *) x \
)
            `
        ),
        D(
            q{
                import std.stdio: writeln;
                int a = 7;
                void *p = &a;
                auto intPtr = void_to_int_ptr(p);
            }
        )
    );
}

@("func")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h",
                  `#define FOO(x) ((x) * 2)
                   #define BAR(x, y) ((x) + (y))
                   #define BAZ(prefix, ...) text(prefix, __VA_ARGS__)
                   #define STR(x) #x
                   #define ARGH(x) STR(I like spaces x)
                   #define NOARGS() ((short) 42)`);

        writeFile("foo.dpp",
                  [`#include "hdr.h"`,
                   `import std.conv : text;`]);
        writeFile("bar.d",
                  q{
                      import foo;
                      static assert(FOO(2) == 4);
                      static assert(FOO(3) == 6);
                      static assert(BAR(2, 3) == 5);
                      static assert(BAR(3, 4) == 7);
                      static assert(BAZ("prefix_", 42, "foo") == "prefix_42foo");
                      static assert(BAZ("prefix_", 42, "foo", "bar") == "prefix_42foobar");
                      static assert(NOARGS() == 42);
                  });

        runPreprocessOnly("--function-macros", "foo.dpp");
        shouldCompile("foo.d");
        shouldCompile("bar.d");
    }
}

@("cast.param")
@safe unittest {
    shouldCompile(
        C(
            `
                #define MEMBER_SIZE(T, member) sizeof(((T*)0)-> member)
                struct Struct { int i; };
            `
        ),
        D(
            q{
                static assert(MEMBER_SIZE(Struct, i) == 4);
            }
        ),
    );
}

@("cast.uchar")
@safe unittest {
    shouldCompile(
        C(
            `
                #define CHAR_MASK(c) ((unsigned char)((c) & 0xff))
            `
        ),
        D(
            q{
                static assert(CHAR_MASK(0xab) == 0xab);
                static assert(CHAR_MASK(0xf1) == 0xf1);
                static assert(CHAR_MASK(0x1f) == 0x1f);
                static assert(CHAR_MASK(0xff) == 0xff);
            }
        ),
    );
}

@("dowhile")
@safe unittest {
    shouldCompile(
        C(
            `
#define Py_BUILD_ASSERT(cond)  do {         \
        (void)Py_BUILD_ASSERT_EXPR(cond);   \
    } while(0)
            `
        ),
        D(
            q{
            }
        ),
        ["--function-macros"],
    );

}

@("vartype")
@safe unittest {
    shouldCompile(
        C(
            `
                #define DOC_VAR(name) static const char name[]
            `
        ),
        D(
            q{
            }
        ),
        ["--function-macros"],
    );
}
