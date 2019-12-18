/**
   Github issues.
 */
module it.issues;

import it;

version(Posix) // because Windows doesn't have signinfo
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
@("7.0")
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

@Tags("issue", "bitfield")
@("7.1")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct other {
                    int a: 2;
                    int b: 3;
                    // field type of pointer to undeclared struct should not
                    // affect the generated bitfields' syntax
                    struct A *ptr;
                };
            }
        ),
        D(
            q{
                other o;
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

@Tags("issue", "preprocessor")
@("22.2")
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
@("22.3")
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
@("29.4")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct Struct {
                    union {
                        int a;
                        struct {
                            int b;
                            union {
                                int c;
                                char d;
                            };
                        };
                    };
                };
            }
        ),
        D(
            q{
                Struct s;
                s.a = 42;
                s.b = 1337;
                s.c = 7;
                s.d = 'D';
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
                // The declaration `int (f)(int x, int y)` is of a function
                // parameter that has the type of a binary function that
                // returns int. Because C is C, this is similar to writing
                // `int f[16]` in a parameter list but actually declaring
                // `int*`. The result is a parameter that's a function pointer
                // instead. To make things worse, if you put parens around the
                // parameter name as is done here, the cursor's type according
                // to libclang (in older versions) goes from FunctionProto to
                // Unexposed because "reasons".
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


version(linux) // linux specific header in the test
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
@("76")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <typename T>
                struct Template {
                    T payload;
                };
            }
        ),
        D(
            q{
                static assert(__traits(getProtection, Template!int.payload) == "public",
                              __traits(getProtection, Template!int.payload));
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
                              // before the BAR macro, BAR is 42. After, it's 33.
                          `,
                          D(""), // no need for .dpp source code
        );
        writeFile("2nd.h",
                  `
                      // These empty lines are important, since they push the enum
                      // declaration down to have a higher line number than the BAR macro.
                      // The bug had to do with ordering.
                      enum TheEnum { BAR = 42 };
                  `);
        run("-c", inSandboxPath("app.dpp"), "--keep-pre-cpp-files");
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
@("95")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                constexpr int x = sizeof(int) + alignof(int) + sizeof(int);
            }
        ),
        D(
            q{
                static assert(x == 12);
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
                public:
                    int i;
                };

                template<int I>
                class T2 {
                public:
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


@Tags("issue")
@("99")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class A {
                public:
                    constexpr static int i = 0;
                    constexpr static int j = A::i;
                };
            }
        ),
        D(
            q{
                static assert(A.i == 0);
                static assert(A.j == 0);
            }
        ),
    );
}


@ShouldFail("cursor.enumConstantValue returning 0 for `value = I`")
@Tags("issue")
@("100")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class T1 {
                    enum { value = 42 };
                };

                template<int I>
                class T2 {
                    enum { value = I };
                };
            }
        ),
        D(
            q{
                static assert(T1.value == 42);
                static assert(T2!2.value == 2);
                static assert(T2!3.value == 3);
            }
        ),
    );
}


@Tags("issue")
@("101")
@safe unittest {
    // SO tells me the standard insists upon unsigned long long
    // and apparently so does MSVC... but linux doesn't. idk why.
    // see: https://stackoverflow.com/a/16596909/1457000
    version(Windows)
        string type = "unsigned long long";
    else
        string type = "unsigned long";
    shouldCompile(
        Cpp(
            q{
                // normally without the underscore
                int operator "" _s(const wchar_t* __str, } ~ type ~ q{ __len);
            }
        ),
        D(
            q{
            }
        ),
    );
}


@Tags("issue")
@("103.0")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h",
                  "#define CONSTANT 42\n");
        writeFile("hdr.dpp",
                  `
                      #include "hdr.h"
                  `);
        writeFile("app.d",
                  q{
                      import hdr;
                      static assert(CONSTANT == 42);
                  });

        runPreprocessOnly("hdr.dpp");
        shouldCompile("app.d");
    }
}


@Tags("issue")
@("103.1")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h",
                  "#define OCTAL 00177\n");
        writeFile("hdr.dpp",
                  `
                      #include "hdr.h"
                  `);
        writeFile("app.d",
                  q{
                      import hdr;
                      static assert(OCTAL == 127);
                  });

        runPreprocessOnly("hdr.dpp");
        shouldCompile("app.d");
    }
}


@Tags("issue")
@("103.2")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h",
                  "#define STRING \"foobar\"\n");
        writeFile("hdr.dpp",
                  `
                      #include "hdr.h"
                  `);
        writeFile("app.d",
                  q{
                      import hdr;
                      static assert(STRING == "foobar");
                  });

        runPreprocessOnly("hdr.dpp");
        shouldCompile("app.d");
    }
}


@Tags("issue")
@("103.3")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h",
                  `
                      #define BASE 5
                      #define OPT0 (BASE * 16 + 0)
                      #define OPT1 (BASE * 16 + 1)
                  `
        );
        writeFile("hdr.dpp",
                  `
                      #include "hdr.h"
                  `);
        writeFile("app.d",
                  q{
                      import hdr;
                      static assert(BASE == 5);
                      static assert(OPT0 == 80);
                      static assert(OPT1 == 81);
                  });

        runPreprocessOnly("hdr.dpp");
        shouldCompile("app.d");
    }
}



@ShouldFail
@Tags("issue")
@("104")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template <int> struct Struct{};
                template<>
                struct Struct<1 + 1> {
                    static constexpr auto value = 42;
                };
            }
        ),
        D(
            q{
                static assert(Struct!2.value == 42);
            }
        ),
   );
}


@Tags("issue")
@("108")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<class T1, class T2, int I>
                class A {};

                template <typename CC> class C {};

                template<>
                class A<C<int>, double, 42> {};
            }
        ),
        D(
            q{

            }
        ),
    );
}


@Tags("issue")
@("109")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<typename C> class Test
                {
                    bool operator==(const Test<C>& x) const { return 0; }
                    bool operator<(const Test<C>& x)  const { return 0; }
                    bool operator>(const Test<C>& x)  const { return 0; }
                };
            }
        ),
        D(
            q{
                const t = Test!int();
                const eq = t == t;
                const lt = t < t;
                const gt = t > t;
            }
        ),
    );
}


@Tags("issue")
@("110")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                class A {
                    bool operator_a() const;
                };
            }
        ),
        D(
            q{
                auto a = new const A;
                bool ret = a.operator_a();
            }
        ),
    );
}



@Tags("issue", "namespace")
@("113")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                // the issue here was nested namespaces
                namespace ns1 {
                    namespace ns2 {
                        struct Struct;

                        template<typename T>
                            struct Template {
                        };

                        class Class;  // should be ignored but isn't
                        class Class: public Template<Struct> {
                            int i;
                        };
                    }
                }
            }
        ),
        D(
            q{
            }
        ),
    );
}


@Tags("issue")
@("114")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<class T>
                struct Foo {
                    template<class U>
                    Foo& operator=(U& other) {
                        return *this;
                    }
                };
            }
        ),
        D(
            q{
                Foo!int foo;
                int i;
                foo = i;
                double d;
                foo = d;
            }
        ),
    );
}


@Tags("issue")
@("115")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                template<class T>
                class Foo {
                    T value;
                public:
                    Foo(T value);
                };

                template<class T>
                Foo<T>::Foo(T val) {
                    value = val;
                }
            }
        ),
        D(
            q{
                auto fooI = Foo!int(42);
                auto fooD = Foo!double(33.3);
            }
        ),
    );
}


@Tags("issue")
@("116")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo;
                struct Foo { int i; };
            }
        ),
        D(
            q{
                static assert(is(typeof(Foo.i) == int));
            }
        ),
    );
}


@Tags("issue")
@("119.0")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Struct {
                    enum Enum { foo, bar, baz };
                };

                void fun(Struct::Enum);
            }
        ),
        D(
            q{
            }
        ),
    );
}


@Tags("issue")
@("119.1")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Struct {
                    enum class Enum { foo, bar, baz };
                };
            }
        ),
        D(
            q{
                auto f = Struct.Enum.foo;
                static assert(!__traits(compiles, Struct.foo));
            }
        ),
    );
}


@ShouldFail("libclang fails to tokenise this for some reason")
@Tags("issue", "libclang")
@("119.2")
@safe unittest {
    with(immutable IncludeSandbox()) {

        writeFile("util.hpp",
                  `
                      #define MAKE_ENUM_CLASS(type, values) enum class type { values };
                  `);

        writeFile("hdr.hpp",
                  `
                      #include "util.hpp"
                      #define VALUES X(foo) X(bar) X(baz)
                      #define X(n) n,
                          MAKE_ENUM_CLASS(Enum, VALUES)
                      #undef X
                  `);

        writeFile("app.dpp",
                  `
                  #include "hdr.hpp"
                  void main() {
                      auto f = Enum.foo;
                      static assert(!__traits(compiles, foo));
                  }
                  `);

        runPreprocessOnly(["app.dpp"]);
        shouldCompile("app.d");
    }
}


@Tags("issue")
@("134")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo {
                    double fun(int i) const;
                };

                double Foo::fun(int i) const {
                    return i * 2;
                }
            }
        ),
        D(
            q{
                auto foo = Foo();
                double d = foo.fun(42);
            }
        ),
    );
}


@Tags("namespace", "issue")
@("149")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace ns {
                    struct Struct;

                    template<typename T>
                    struct Template { };

                    // The `Struct` template parameter must be translated properly
                    // and was showing up as ns.Struct
                    class Class: public Template<Struct> {
                        int i;
                    };
                }
            }
        ),
        D(
            q{
            }
        ),
    );
}


@Tags("issue")
@("150")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct Foo {
                    int a, b, c;
                };

                struct Bar {
                    Foo& foo;
                };
            }
        ),
        D(
            q{
                import std.conv: text;
                static assert(Foo.sizeof == 12, Foo.sizeof.text);
                static assert(Foo.alignof == 4, Foo.alignof.text);
                static assert(Bar.sizeof == 8, Bar.sizeof.text);
                static assert(Bar.alignof == 8, Bar.alignof.text);
            }
        ),
    );
}


@Tags("issue")
@("151")
@safe unittest {
    shouldRun(
        Cpp(
            q{
                struct Foo {
                    long data;
                };

                struct Bar {
                    static long numDtors;
                    long data;
                    ~Bar();
                };

                Foo makeFoo();
                Bar makeBar();
            }
        ),
        Cpp(
            q{
                Foo makeFoo() { return {}; }
                Bar makeBar() { return {}; }
                Bar::~Bar() { ++numDtors; }
                long Bar::numDtors;
            }
        ),
        D(
            q{
                import std.conv: text;

                auto foo = makeFoo;
                assert(foo.data == 0, foo.data.text);

                {
                    auto bar = makeBar;
                    assert(bar.data == 0, bar.data.text);
                    bar.data = 42;
                    assert(bar.numDtors == 0, bar.numDtors.text);
                }

                assert(Bar.numDtors == 1, Bar.numDtors.text);
            }
        ),
    );
}


@("missing.template.parameter")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace myns {
                    template<typename T>
                    struct vector {
                        T* elements;
                        long size;
                    };
                }

                struct Problem {
                    // In the issue this gets emitted as `vector values`
                    // instead of `vector!double values`
                    myns::vector<double> values;
                };

                Problem createProblem();
            }
        ),
        D(
            q{
            }
        ),
   );
}

@Tags("issue")
@("168")
// @("gcc.__extention__")
// Examples:
//    /usr/include/netinet/in.h
//    /usr/include/x86_64-linux-gnu/bits/cpu-set.h
@safe unittest {
    shouldCompile(
        C(
            `
                #define FOO(bar) {__extension__({bar;})
            `
        ),
        D(
            q{
            }
        )
    );
}


@Tags("issue")
@("172")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                struct virtual_base {
                    virtual_base() = default;
                    virtual ~virtual_base() = default;
                    virtual_base(virtual_base&&) = default;
                    virtual_base(const virtual_base&) = default;
                    virtual_base& operator=(virtual_base&&) = default;
                    virtual_base& operator=(const virtual_base&) = default;
                };
            }
        ),
        D(
            q{
            }
        )
    );
}


@HiddenTest("Needs the cl_platform.h header on the machine")
@Tags("issue")
@("175")
@safe unittest {
    shouldCompile(
        C(
            `
#include "CL/cl_platform.h"
            `
        ),
        D(
            q{
            }
        )
    );
}


@Tags("issue")
@("207")
@safe unittest {
    shouldCompile(
        C(
            `
                #define FOO 1
                #define BAR 2
                #define BAZ 4
                #define ALL ( \
                    FOO | \
                    BAR | \
                    BAZ \
                )
            `
        ),
        D(
            q{
                static assert(ALL == 7);
            }
        )
    );
}


version(Linux) {
    @Tags("issue")
        @("229.0")
        @safe unittest {
        with(immutable IncludeSandbox()) {
            writeFile(`app.dpp`,
                      `
                          module foo.linux.bar;
                      `
            );
            runPreprocessOnly("app.dpp");
            shouldNotCompile("app.d");
        }
    }


    @Tags("issue")
        @("229.1")
        @safe unittest {
        with(immutable IncludeSandbox()) {
            writeFile(`app.dpp`,
                      `
                          #undef linux
                          module foo.linux.bar;
                      `
            );
            runPreprocessOnly("app.dpp");
            shouldCompile("app.d");
        }
    }
}
