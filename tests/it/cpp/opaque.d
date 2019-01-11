module it.cpp.opaque;


import it;


@("vector")
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
