module it.cpp.opaque;


import it;


@("field")
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
