module it.cpp.opaque;


import it;


@("field.private")
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
                    long length();
                private:
                    myns::vector<double> values;
                };

                Problem createProblem();
            }
        ),
        D(
            q{
                // this should have been ignored
                static assert(!is(vector!double));
                static assert(Problem.sizeof == 16);
                auto problem = Problem();
                long l = problem.length();
            }
        ),
        ["--ignore-ns", "myns"],
   );
}


@("field.public")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.hpp",
                  q{
                      namespace oops {
                          struct Date {};
                      }

                      struct DateUser {
                          // Using it as a parameter caused dpp to define it for
                          // the user in `Context.declaredUnknownStructs`/
                          // This prevents the user from defining it.
                          void fun(oops::Date*);
                      };

                      struct Foo {
                          // these need to be made opaque
                          oops::Date start;
                          oops::Date end;
                      };

                  });
        writeFile("app.dpp",
                  `
                      #include "hdr.hpp"
                      struct Date{} // the definition will be skipped
                      void main() {
                      }
                  `);
        runPreprocessOnly(["--ignore-ns", "oops", "app.dpp"]);
        shouldCompile("app.d");
    }
}


@("field.static")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace oops {
                    struct Widget {};
                }

                class Foo {
                private:
                    // this is private so shouldn't show up
                    static oops::Widget widget;
                };
            }
        ),
        D(
            q{
            }
        ),
        ["--ignore-ns", "oops"],
   );
}


@ShouldFail
@("base")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace myns {
                    struct Base{};
                }

                struct Derived: public myns::Base {

                };
            }
        ),
        D(
            q{
                auto derived = Derived();
            }
        ),
        ["--ignore-ns", "myns"],
   );
}


@("parameter.ref.const")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.hpp",
                  q{
                      namespace myns {
                          struct Forbidden{};
                      }

                      struct Foo {
                          void fun(const myns::Forbidden&);
                      };
                  });
        writeFile("app.dpp",
                  `
                      #include "hdr.hpp"
                      struct Forbidden;
                      void main() {
                      }
                  `);
        runPreprocessOnly(["--ignore-ns", "myns", "app.dpp"]);
        shouldCompile("app.d");
    }
}


@("parameter.value")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace myns {
                    struct Forbidden{
                        int i;
                    };
                }

                struct Foo {
                    void fun(myns::Forbidden);
                };
            }
        ),
        D(
            q{
                dpp.Opaque!4 forbidden = void;
                auto foo = Foo();
                foo.fun(forbidden);
            }
        ),
        ["--ignore-ns", "myns"],
   );
}



@("return.ref.const")
@safe unittest {

    with(immutable IncludeSandbox()) {
        writeFile("hdr.hpp",
                  q{
                      namespace myns {
                          struct Forbidden{};
                      }

                      struct Foo {
                          const myns::Forbidden& fun();
                      };
                  });
        writeFile("app.dpp",
                  `
                      #include "hdr.hpp"
                      struct Forbidden;
                      void main() {
                      }
                  `);
        runPreprocessOnly(["--ignore-ns", "myns", "app.dpp"]);
        shouldCompile("app.d");
    }
}


@("return.value")
@safe unittest {
    shouldCompile(
        Cpp(
            q{
                namespace myns {
                    struct Forbidden{
                        int i;
                    };
                }

                struct Foo {
                    myns::Forbidden fun();
                };
            }
        ),
        D(
            q{
                auto foo = Foo();
                auto blob = foo.fun();
                static assert(is(typeof(blob.bytes) == void[4]));
            }
        ),
        ["--ignore-ns", "myns"],
   );
}


@("parameter.vector")
@safe unittest {

    with(immutable IncludeSandbox()) {
        writeFile("hdr.hpp",
                  q{
                      namespace oops {
                          template<typename T>
                              struct vector {};
                      }

                      namespace myns {
                          struct Foo {};
                      }

                      // make sure the paremeter gets translated correctly
                      void fun(oops::vector<myns::Foo>&);
                  });
        writeFile("app.dpp",
                  `
                      #include "hdr.hpp"
                      struct vector(T);
                      void main() {
                      }
                  `);
        runPreprocessOnly(["--ignore-ns", "oops", "app.dpp"]);
        shouldCompile("app.d");
    }
}


@("parameter.exception_ptr")
@safe unittest {

    with(immutable IncludeSandbox()) {
        writeFile("hdr.hpp",
                  q{
                      namespace oops {
                          namespace le_exception_ptr {
                              class exception_ptr;
                          }
                          using le_exception_ptr::exception_ptr;
                      }

                      // make sure the parameter gets translated correctly
                      // It's referred to as oops::exception_ptr and that's what
                      // libclang will see, but its real name is
                      // oops::le_exception_ptr::exception_ptr
                      void fun(const oops::exception_ptr&);
                  });
        writeFile("app.dpp",
                  `
                      #include "hdr.hpp"
                      struct exception_ptr;
                      void main() {
                      }
                  `);
        runPreprocessOnly(["--ignore-ns", "oops", "app.dpp"]);
        shouldCompile("app.d");
    }
}


@("std::function")
@safe unittest {

    with(immutable IncludeSandbox()) {
        writeFile("hdr.hpp",
                  q{
                      // analogous to std::function
                      namespace oops {
                          template<typename> struct function;
                          template<typename R, typename... Args>
                          struct function<R(Args...)> {};
                      }

                      using Func1D = oops::function<double(double)>;

                      struct Solver {
                          double solve(const Func1D&, double, double);
                      };

                      // It's important that the return type be explicitly
                      // oops::function* instead of Func1D
                      oops::function<double(double)>* newFunction1D(int);
                  });
        writeFile("app.dpp",
                  `
                      #include "hdr.hpp"
                      import std.traits: Parameters;

                      struct function_(T) {}

                      alias FuncPtr = extern(C++) double function(double);
                      alias FuncType = typeof(*(FuncPtr.init));
                      alias ParamType = Parameters!(Solver.solve)[0];
                      pragma(msg, "ParamType: ", ParamType);
                      static assert(is(ParamType == const(function_!FuncType)));

                      void main() {
                          auto f = newFunction1D(42);
                      }
                  `);
        runPreprocessOnly(["--hard-fail", "--detailed-untranslatable", "--ignore-ns", "oops", "app.dpp"]);
        shouldCompile("app.d");
    }
}
