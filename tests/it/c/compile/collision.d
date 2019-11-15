/**
   Tests for declarations that must be done at the end when they
   haven't appeared yet (due to pointers to undeclared structs)
 */
module it.c.compile.collision;

import it;

@Tags("collision")
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

@Tags("collision")
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

@Tags("collision")
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


@Tags("collision", "issue", "issue24")
@("Old issue 24")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct _mailstream_low mailstream_low;
                struct mailstream_cancel* mailstream_low_get_cancel(void);
                struct _mailstream {
                    struct mailstream_cancel* idle;
                };

                struct mailstream_low_driver {
                    void (*mailstream_cancel)(int);
                    struct mailstream_cancel* (*mailstream_get_cancel)(mailstream_low*);
                };

                int mailstream_low_wait_idle(struct mailstream_cancel*);

                struct _mailstream_low {
                    void* data;
                    struct mailstream_low_driver* driver;
                    int privacy;
                    char* identifier;
                    unsigned long timeout;
                    void* logger_context;
                };
            }
        ),
        D(
            q{
                // should just compile
            }
        ),
    );
}

@Tags("collision")
@("Undeclared struct pointer in function pointer field return type")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    struct Foo* (*func)(void);
                };
            }
        ),
        D(
            q{
                Struct s;
                Foo* foo = s.func();
            }
        ),
    );
}

@Tags("collision")
@("Undeclared struct pointer in function pointer field param type")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    void (*func)(struct Foo*, struct Bar*);
                };
            }
        ),
        D(
            q{
                Foo* foo;
                Bar* bar;
                Struct s;
                s.func(foo, bar);
            }
        ),
    );

}


@Tags("collision")
@("foo and foo_ cause function foo to renamed as foo__")
@safe unittest {
    shouldCompile(
        C(
            q{
                void foo(void);
                // Struct causes the function to be named foo_
                struct Struct { struct foo* field; };
                struct foo_ { int dummy; };
            }
        ),
        D(
            q{
                Struct s;
                static assert(is(typeof(s.field) == foo*));
                foo_ f;
                f.dummy = 42;
                foo__();
            }
        ),
    );
}

@Tags("collision")
@("struct module and void module() should be renamed differently")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct module;
                void module(struct module const * const ptr);
                struct module { struct module *module_; };
            }
        ),
        D(
            q{
                module_ md;
                md.module__ = &md;
                module__(md.module__);
            }
        ),
    );
}

@Tags("collision")
@("Accessors for members of anonymous records are renamed")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct A {
                    union {
                        unsigned int version;
                        char module;
                    };
                    int a;
                };
            }
        ),
        D(
            q{
                A a;
                a.version_ = 7;
                a.module_ = 'D';
            }
        ),
    );
}

@Tags("collision")
@("Members (pointers to struct) in multiple (possibly anon) structures")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct A;

                struct B {
                    struct A *A;
                };

                struct C {
                    struct A* A;
                };

                struct D {
                    union {
                        struct A* A;
                        int d;
                    };
                };
            }
        ),
        D(
            q{
                A *a;
                B b;
                b.A_ = a;
                C c;
                c.A_ = a;
                D d;
                d.A_ = a;
            }
        ),
    );
}
