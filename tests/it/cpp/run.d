/**
   C++ tests that must run
 */
module it.cpp.run;

import it;

@Tags("run")
@("function")
@safe unittest {
    shouldCompileAndRun(
        Cpp(
            q{
                int add(int i, int j);
            }
        ),
        Cpp(
            q{
                int add(int i, int j) { return i + j; }
            }
        ),
        D(
            q{
                import std.exception: assertThrown;
                import core.exception: AssertError;
                assert(add(2, 3) == 5, "add(2, 3) should be 5");
                void func() {
                    assert(add(2, 3) == 7);
                }
                assertThrown!AssertError(func(), "add(2, 3) should not be 7");
            }
         ),
    );
}
