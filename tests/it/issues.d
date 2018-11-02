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
        fileShouldContain("issue6.d", q{char* getMessage() @nogc nothrow;});
    }
}


@Tags("issue", "bitfield")
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

@Tags("issue", "preprocessor")
@("22.0")
@safe unittest {
    shouldCompile(
        C(
            `
                typedef struct {
                    #ifdef __USE_XOPEN
                        int fds_bits[42];
                        #define __FDS_BITS(set) ((set)->fds_bits)
                    #else
                        int __fds_bits[42];
                        #define __FDS_BITS(set) ((set)->__fds_bits)
                    #endif
                } fd_set;
            `
        ),
        D(
            q{
                fd_set set;
                __FDS_BITS(set)[0] = 42;
            }
        ),
    );
}

@Tags("issue", "preprocessor")
@("22.1")
@safe unittest {
    shouldCompile(
        C(
            `
                #define SIZEOF(x) (sizeof(x))
            `
        ),
        D(
            q{
                int i;
                static assert(SIZEOF(i) == 4);
            }
        ),
    );
}

@ShouldFail
@Tags("issue", "preprocessor")
@("22.3")
@safe unittest {
    shouldCompile(
        C(
            `
                typedef long int __fd_mask;
                #define __NFDBITS (8 * (int) sizeof (__fd_mask))
            `
        ),
        D(
            q{
                import std.conv;
                static assert(__NFDBITS == 8 * c_long.sizeof,
                              text("expected ", 8 * c_long.sizeof, ", got: ", __NFDBITS));
            }
        ),
    );
}

@Tags("issue", "preprocessor")
@("22.4")
@safe unittest {
    shouldCompile(
        C(
            `
                typedef struct clist { struct list* next; };
                #define clist_next(iter) (iter ? (iter)->next : NULL)
            `
        ),
        D(
            q{
                clist l;
                auto next = clist_next(&l);
            }
        ),
    );
}



@Tags("issue", "collision", "issue24")
@("24.0")
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

@Tags("issue", "collision", "issue24")
@("24.1")
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


@Tags("issue")
@("29.0")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct {
                    union {
                        struct {
                            double x;
                            double y;
                            double z;
                        };
                        double raw[3];
                    };
                } vec3d_t;
            }
        ),
        D(
            q{
                vec3d_t v;
                static assert(v.sizeof == 24);
                v.raw[1] = 3.0;
                v.y = 4.0;
            }
        ),
    );
}

@Tags("issue")
@("29.1")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct {
                    struct {
                        int x;
                        int y;
                    };

                    struct {
                        int z;
                    };
                } Struct;
            }
        ),
        D(
            q{
                Struct s;
                s.x = 2;
                s.y = 3;
                s.z = 4;
            }
        ),
    );
}

@Tags("issue")
@("29.2")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    union {
                        unsigned long long int foo;
                        struct {
                            unsigned int low;
                            unsigned int high;
                        } foo32;
                    };
                };
            }
        ),
        D(
            q{
                Struct s;
                s.foo = 42;
                s.foo32.low = 33;
                s.foo32.high = 77;
            }
        ),
    );
}


@Tags("issue")
@("29.3")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    union {
                        unsigned long long int foo;
                        void *bar;
                    };
                };
            }
        ),
        D(
            q{
                Struct s;
                s.foo = 42;
                s.bar = null;
            }
        ),
    );
}


@Tags("issue")
@("33.0")
@safe unittest {
    shouldCompile(
        C(
            q{
                void (*f)();
            }
        ),
        D(
            q{
                static extern(C) void printHello() { }
                f = &printHello;
                f();
            }
        ),
    );
}

@Tags("issue")
@("33.1")
@safe unittest {
    shouldCompile(
        C(
            q{
                int (*f)();
            }
        ),
        D(
            q{
                static extern(C) int func() { return 42; }
                f = &func;
                int i = f();
            }
        ),
    );
}


@Tags("issue", "bitfield")
@("35")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    int foo;
                    int bar;
                    int :32;
                    int :31;
                    int :3;
                    int :27;
                };
            }
        ),
        D(
            q{
                Struct s;
                static assert(s.sizeof == 20);
            }
        ),
    );
}

@Tags("issue")
@("37")
@safe unittest {
    shouldCompile(
        C(
            `
                #include "mmintrin.h"
            `
        ),
        D(
            q{
            }
        ),
    );
}


@Tags("issue", "preprocessor")
@("39.0")
@safe unittest {
    shouldCompile(
        C(
            `
                typedef long value;
                typedef long intnat;
                typedef unsigned long uintnat;
                #define Val_long(x) ((intnat) (((uintnat)(x) << 1)) + 1)
                #define Long_val(x)     ((x) >> 1)
                #define Val_int(x) Val_long(x)
                #define Int_val(x) ((int) Long_val(x))
                #define Bp_val(v) ((char *) (v))
                #define String_val(x) ((const char *) Bp_val(x))
                value caml_callback(value, value);
                char* strdup(const char* val);
            `
        ),
        D(
            q{
                static value* fib_closure = null;
                int n;
                auto val = Int_val(caml_callback(*fib_closure, Val_int(n)));
                char* str = strdup(String_val(caml_callback(*fib_closure, Val_int(n))));
            }
        ),
    );
}

@Tags("issue", "preprocessor")
@("39.1")
@safe unittest {
    shouldCompile(
        C(
            `
                #define VOID_PTR(x) ( void* )(x)
            `
        ),
        D(
            q{
                auto val = VOID_PTR(42);
                static assert(is(typeof(val) == void*));
            }
        ),
    );
}

@Tags("issue", "preprocessor")
@("39.2")
@safe unittest {
    shouldCompile(
        C(
            `
                typedef int myint;
                #define CAST(x) ( myint* )(x)
            `
        ),
        D(
            q{
                auto val = CAST(42);
                static assert(is(typeof(val) == int*));
            }
        ),
    );
}

@Tags("issue", "preprocessor")
@("40")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr1.h",
                  q{
                      typedef int myint;
                  });
        writeFile("hdr2.h",
                  q{
                      myint myfunc(void);
                  });
        writeFile("src.dpp",
                  `
                      #include "hdr1.h"
                      #include "hdr2.h"
                      void func() {
                          myint _ = myfunc();
                      }
                  `);
        runPreprocessOnly("src.dpp");
        shouldCompile("src.d");
    }
}

@Tags("issue")
@("43")
@safe unittest {
    shouldCompile(
        C(
            q{
                int binOp(int (f)(int x, int y), int a, int b);
                int thef(int x, int y);
            }
        ),
        D(
            q{
                binOp(&thef, 2, 3);
            }
        ),
    );
}


@Tags("issue")
@("44.1")
@safe unittest {
    shouldCompile(
        C(
            `
                #define macro(x) (x) + 42
            `
        ),
        D(
            q{
                static assert(macro_(0) == 42);
                static assert(macro_(1) == 43);
            }
        ),
    );
}

@Tags("issue")
@("44.2")
@safe unittest {
    shouldCompile(
        C(
            `
                struct macro { int i };
            `
        ),
        D(
            q{
            }
        ),
    );
}


@Tags("issue")
@("48")
@safe unittest {
    shouldCompile(
        C(
            `
                #include <stddef.h>
                struct Struct {
                    volatile int x;
                    volatile size_t y;
                };
            `
        ),
        D(
            q{

            }
        ),
    );
}

@Tags("issue", "preprocessor")
@("49")
@safe unittest {
    shouldCompile(
        C(
            `
                #define func() ((void)0)
                void (func)(void);
            `
        ),
        D(
            q{
                // it gets renamed
                func_();
            }
        ),
    );
}

@Tags("issue")
@("53")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef int bool;
            }
        ),
        D(
            q{

            }
        ),
    );
}

@Tags("issue", "enum")
@("54")
@safe unittest {
    shouldCompile(
        C(
            q{
                enum {
                    SUCCESS,
                };
                typedef int boolean;
            }
        ),
        D(
            q{
                static assert(SUCCESS == 0);
            }
        ),
    );
}


@Tags("issue")
@("66")
@safe unittest {
    shouldCompile(
        C(
            `
                #include <linux/ethtool.h>
            `
        ),
        D(
            q{
            }
        ),
    );
}

@Tags("issue")
@("77")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h", "");
        writeFile("app.dpp",
                  `
                      module mymodule;
                      #include "hdr.h"
                      void main() {
                          static assert(__MODULE__ == "mymodule");
                      }
                  `);
        runPreprocessOnly("app.dpp");
        shouldCompile("app.d");
    }
}

@Tags("issue")
@("79")
unittest {
    with(const IncludeSandbox()) {
        writeHeaderAndApp("1st.h",
                          `
                              #include "2nd.h"
                              #define BAR 33
                          `,
                          D(""), // no need for .dpp source code
        );
        writeFile("2nd.h",
                  `
                      // these empty lines are important, since they push the enum
                      // declaration down to have a higher line number than the BAR macro.
                      enum TheEnum { BAR = 42 };
                  `);
        run("-c", inSandboxPath("app.dpp"));
    }
}


@Tags("issue")
@("90.0")
@safe unittest {
    shouldCompile(
        C(
            `
                #define TEST(_ARR) ((int)(sizeof(_ARR)/sizeof(*_ARR)))
            `
        ),
        D(
            q{
            }
        ),
    );
}

@Tags("issue")
@("90.1")
@safe unittest {
    shouldCompile(
        C(
            `
                #define TEST(_ARR) ((int)(sizeof(_ARR)/sizeof(_ARR[0])))
            `
        ),
        D(
            q{
                int[8] ints;
                static assert(TEST(ints) == 8);
            }
        ),
    );
}

@Tags("issue")
@("91.0")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <typename T, typename U> class Test {};
                void test(Test<unsigned short, unsigned int> a);
            }
        ),
        D(
            q{
                test(Test!(ushort, uint)());
            }
        ),
    );
}

@Tags("issue")
@("91.1")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <typename T, int> class Test {};
                void test(Test<unsigned short, 42> a);
            }
        ),
        D(
            q{
                test(Test!(ushort, 42)());
            }
        ),
    );
}



@Tags("issue")
@("93")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                constexpr int x = sizeof(int) + (1) + sizeof(int);
            }
        ),
        D(
            q{
                static assert(x == 9);
            }
        ),
    );
}

@Tags("issue")
@("96")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<unsigned long A, int B> class C{
                    enum { value = 0 };
                };
                template<> class C<3,4> {
                    enum { value = 1 };
                };
            }
        ),
        D(
            q{
                static assert(C!(0, 0).value == 0);
                static assert(C!(0, 1).value == 0);
                static assert(C!(1, 0).value == 0);

                static assert(C!(3, 4).value == 1);
            }
        ),
    );
}


@Tags("issue")
@("97")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class T1 {
                    enum { value = 42 };
                    int i;
                };

                template<int I>
                class T2 {
                    enum { value = I };
                    double d;
                };

                extern T1 a;
                extern T2<3> b;
            }
        ),
        D(
            q{
                a.i = 33;
                b.d = 33.3;
            }
        ),
    );
}
