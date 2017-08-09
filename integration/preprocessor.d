module integration.preprocessor;

import unit_threaded;
import include.runtime;


@("define macro, undefine, then define again")
@safe unittest {

    import std.stdio: File;
    import std.process: execute;
    import std.path: buildPath;
    import std.format: format;

    with(immutable Sandbox()) {

        const headerFileName = "header.h";

        writeFile(headerFileName,
                  q{
                      #define FOO foo
                      #undef FOO
                      #define FOO bar
                      int FOO(int i);
                  });


        const fullHeaderFileName = buildPath(testPath, headerFileName);
        const inputFileName = "foo.d";
        writeFile(inputFileName,
                  q{
                      #include "%s"
                      void func() {
                          int i = bar(2);
                      }
                  }.format(fullHeaderFileName));


        const fullInputFileName = buildPath(testPath, inputFileName);
        const fullOutputFileName = buildPath(testPath, "foo.d");
        preprocess!File(fullInputFileName, fullOutputFileName);

        const objectFileName = buildPath(testPath, "foo.o");

        const result = execute(["dmd", "-of" ~ objectFileName, "-c", fullOutputFileName]);
        if(result.status != 0)
            throw new Exception("Could not build the resulting file:\n" ~ result.output);
    }
}
