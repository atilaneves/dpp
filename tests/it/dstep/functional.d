/**
   Tests "inspired" by the ones in dstep's functional directory
 */
module it.dstep.functional;

import it.compile;

@ShouldFail
@("const int")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("dstep.d"), In("dstep.h"),
               q{
                   const int a; // const int
                   const int* b; // mutable pointer to const int
                   int* const c; // const pointer to mutable int
                   const int* const d; // const pointer to const int
                   const int* const * e; // mutable pointer to const pointer to const int
                   const int* const * const f; // const pointer to const pointer to const int
                   int* const * const g; // const pointer to const pointer to mutable int
               });

        writeFile("main.d",
                  q{
                      import dstep;
                      void assertType(E, A, string file = __FILE__, size_t line = __LINE__)
                                     (auto ref A t)
                      {
                          import std.conv: text;
                          static assert(is(A == E),
                                        text(file, ":", line, " Expected: ", E.stringof,
                                             "  Got: ", A.stringof));
                      }

                      void main() {
                          a.assertType!(const int);
                          b.assertType!(const(int)*);
                          c.assertType!(int*);
                          d.assertType!(const int*);
                          e.assertType!(const(int*)*);
                          f.assertType!(const int**);
                          g.assertType!(int**);
                      }
                  });

        shouldCompile("main.d", "dstep.d");
    }
}

@ShouldFail
@("const struct")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("dstep.d"), In("dstep.h"),
               q{
                   typedef struct { int i; } Struct;
                   const Struct a; // const Struct
                   const Struct* b; // mutable pointer to const Struct
                   Struct* const c; // const pointer to mutable Struct
                   const Struct* const d; // const pointer to const Struct
                   const Struct* const * e; // mutable pointer to const pointer to const Struct
                   const Struct* const * const f; // const pointer to const pointer to const Struct
                   Struct* const * const g; // const pointer to const pointer to mutable Struct
               });

        writeFile("main.d",
                  q{
                      import dstep;
                      void assertType(E, A, string file = __FILE__, size_t line = __LINE__)
                                     (auto ref A t)
                      {
                          import std.conv: text;
                          static assert(is(A == E),
                                        text(file, ":", line, " Expected: ", E.stringof,
                                             "  Got: ", A.stringof));
                      }

                      void main() {
                          a.assertType!(const Struct);
                          b.assertType!(const(Struct)*);
                          c.assertType!(Struct*);
                          d.assertType!(const Struct*);
                          e.assertType!(const(Struct*)*);
                          f.assertType!(const Struct**);
                          g.assertType!(Struct**);
                      }
                  });

        shouldCompile("main.d", "dstep.d");
    }
}

@("dynamic")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("dstep.d"), In("dstep.h"),
               q{
                   typedef struct
                   {
                       int x;
                       int[0] data;
                   } Dynamic;
               });

        writeFile("main.d",
                  q{
                      import dstep;
                      void main() {
                          import core.stdc.stdlib: malloc;
                          auto d = cast(Dynamic*)malloc(Dynamic.sizeof + 5 * int.sizeof);
                          d.x = 42;
                          // out of bounds
                          static assert(!__traits(compiles, d.data[3]));
                          auto ptr = d.data.ptr;
                          ptr[3] = 77;
                      }
                  });

        shouldCompile("main.d", "dstep.d");
    }
}

@ShouldFail("Unexposed function pointer types")
@("function_pointers")
@safe unittest {
    with(immutable IncludeSandbox()) {
        expand(Out("dstep.d"), In("dstep.h"),
               q{
                   void (*a) (void);
                   int (*b) (void);
                   void (*c) (int);
                   int (*d) (int, int);
                   int (*e) (int a, int b);
                   int (*f) (int a, int b, ...);
               });

        writeFile("main.d",
                  q{
                      import dstep;
                      void main() {
                          static assert(is(typeof(a.init()) == void));
                          static assert(is(typeof(b.init()) == int));
                          c.init(42);
                          int dres = d.init(2, 3);
                          int eres = e.init(4, 5);
                          int fres = f.init(6, 7, 9.0, null);
                          static assert(!__traits(compiles, f.init(6)));
                          static assert(!__traits(compiles, f.init(6, 9.0)));
                      }
                  });

        shouldCompile("main.d", "dstep.d");
    }
}
