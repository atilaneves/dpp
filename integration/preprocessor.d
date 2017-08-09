module integration.preprocessor;

import unit_threaded;
import include.runtime;


@("define macro, undefine, then define again")
@safe unittest {

    import std.stdio: File;
    import std.process: execute;

    with(immutable Sandbox()) {

        const headerFileName = "simple_header.h";

        writeFile(headerFileName,
                  q{
                      #define FOO foo
                      #undef
                      #define FOO bar
                      int FOO(int i);
                  });
        const fullHeaderFileName = buildPath(testPath, fileName);
        const fullOutputFileName = buildPath(testPath, "foo.d");
        preprocess!File(fullHedaerFileName, fullOutputFileName);

        const objectFileName = buildPath(testPath, "foo.o");

        const result = execute(["dmd", "-of" ~ objectFileName, "-c", fullOutputFileName]);
        if(result.status != 0)
            throw new Exception("Could not build the resulting file:\n" ~ result.output);
    }
}
