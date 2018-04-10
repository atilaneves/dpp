/**
   Github issues.
 */
module it.issues;

import it;

@Tags("issue")
@("3")
@safe unittest {
    shouldCompile(
        C(
            `
                #include <signal.h>
            `
        ),
        D(
            q{
                siginfo_t si;
                si._sifields._timer.si_tid = 2;
                static assert(is(typeof(si.si_signo) == int));
                static assert(is(typeof(si._sifields._timer.si_tid) == int),
                              typeof(si._sifields._timer.si_tid).stringof);
            }
        ),
    );
}


@Tags("issue")
@("4")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("issue4.h",
                  q{
                      extern char *arr[9];
                  });
        writeFile("issue4.dpp",
                  `
                   #include "issue4.h"
                  `);
        runPreprocessOnly("issue4.dpp");
        fileShouldContain("issue4.d", q{extern __gshared char*[9] arr;});
    }
}

@Tags("issue")
@("5")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef enum zfs_error {
                    EZFS_SUCCESS = 0,
                    EZFS_NOMEM = 2000,
                };

                typedef struct zfs_perm_node {
                    char z_pname[4096];
                } zfs_perm_node_t;

                typedef struct libzfs_handle libzfs_handle_t;
            }
        ),
        D(
            q{
                zfs_error e1 = EZFS_SUCCESS;
                zfs_error e2 = zfs_error.EZFS_SUCCESS;
                zfs_perm_node_t node;
                static assert(node.z_pname.sizeof == 4096);
                static assert(is(typeof(node.z_pname[0]) == char), (typeof(node.z_pname[0]).stringof));
                libzfs_handle_t* ptr;
            }
        ),
    );
}

@Tags("issue")
@("6")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("issue6.h",
                  q{
                      char *getMessage();
                  });
        writeFile("issue6.dpp",
                  `
                   #include "issue6.h"
                  `);
        runPreprocessOnly("issue6.dpp");
        fileShouldContain("issue6.d", q{char* getMessage();});
    }
}


@Tags("issue")
@("7")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct splitflags {
                    int dryrun : 1;
                    int import : 2;
                    int name_flags;
                    int foo: 3;
                    int bar: 4;
                    int suffix;
                };

                struct other {
                    int quux: 2;
                    int toto: 3;
                };
            }
        ),
        D(
            q{
                static assert(splitflags.sizeof == 16);
                static assert(other.sizeof == 4);
            }
        ),
    );
}

@Tags("issue")
@("10")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum silly_name {
                    FOO,
                    BAR,
                    BAZ,
                };

                extern void silly_name(enum silly_name thingie);
            }
        ),
        D(
            q{
                silly_name_(silly_name.FOO);
            }
        ),
    );
}

@Tags("issue")
@("11")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Foo;
                typedef struct Foo* FooPtr;
            }
        ),
        D(
            q{
                FooPtr f = null;
                static assert(!__traits(compiles, Foo()));
            }
        ),
    );
}

@Tags("issue")
@("14")
@safe unittest {
    import dpp.runtime.options: Options;
    with(immutable IncludeSandbox()) {

        writeFile("foo.h",
                  q{
                      typedef int foo;
                  });

        runPreprocessOnly("foo.h").shouldThrowWithMessage(
            "No .dpp input file specified\n" ~ Options.usage);
    }
}


@Tags("issue", "collision", "issue24")
@("24.1")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Bar {
                    void (*Foo)(void); // this should get renamed as Foo_
                    struct Foo* (*whatever)(void);
                };
            }
        ),
        D(
            q{
            }
        ),
    );
}

@ShouldFail
@Tags("issue", "collision", "issue24")
@("24.2")
@safe unittest {
    shouldCompile(
        C(
            q{
                int foo(int, struct foo_data**);
                struct foo { int dummy; };
                struct foo_data { int dummy; };
            }
        ),
        D(
            q{
                foo_data** data;
                int ret = foo_(42, data);
                foo s;
                s.dummy = 33;
                foo_data fd;
                fd.dummy = 77;
            }
        ),
    );
}
