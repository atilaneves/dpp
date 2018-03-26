module it.compile.function_;

import it.compile;

@("nn_strerror")
@safe unittest {
    with(const IncludeSandbox()) {

        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   const char *nn_strerror (int errnum);
               });

        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          int err = 42;
                          const(char)* str = nn_strerror(err);
                      }
                  });

        shouldCompile("app.d", "hdr.d");
    }
}


@("int function(const(char)*)")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef int (*function_t)(const char*);
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      void maid() {
                          int ret = function_t.init("foobar".ptr);
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}

@("const(char)* function(double, int)")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef const char* (*function_t)(double, int);
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      void maid() {
                          const(char)* ret = function_t.init(33.3, 42);
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}

@("void function()")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef void (*function_t)(void);
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      import std.traits;
                      import std.meta;
                      void maid() {
                          auto f = function_t();
                          static assert(is(ReturnType!f == void));
                          static assert(is(Parameters!f == AliasSeq!()));
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}

@("variadic")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   void fun(int, ...);
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      void maid() {
                          fun(42);
                          fun(42, 33);
                          fun(42, 33.3);
                          fun(42, "foobar".ptr);
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}

@("old uts")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   struct Foo { int value; };
                   struct Bar { int value; };
                   struct Foo addFoos(struct Foo* foo1, struct Foo* foo2);
                   struct Bar addBars(const struct Bar* bar1, const struct Bar* bar2);
                   const char *nn_strerror (int errnum);
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      void maid() {
                          auto f1 = struct_Foo(2);
                          auto f2 = struct_Foo(3);
                          struct_Foo f = addFoos(&f1, &f2);
                          const b1 = struct_Bar(2);
                          const b2 = struct_Bar(3);
                          struct_Bar b = addBars(&b1, &b2);
                          const(char*) msg = nn_strerror(42);
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}
