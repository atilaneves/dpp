module integration.typedefs;

import unit_threaded;
import include.runtime;


//@ShouldFail("WIP")
@("typedef unnamed struct")
@safe unittest {

    import std.stdio: File;
    import std.process: execute;
    import std.path: buildPath;
    import std.format: format;
    import std.exception: enforce;

    with(immutable Sandbox()) {

        const headerFileName = "header.h";

        writeFile(headerFileName,
                  q{
                      typedef struct { int __val[2]; } __fsid_t;
                      typedef __fsid_t fsid_t;
                  });


        const fullHeaderFileName = buildPath(testPath, headerFileName);
        const inputFileName = "foo.d_";
        writeFile(inputFileName,
                  q{
                      #include "%s"
                      void func() {
                          fsid_t foo;
                          foo.__val[0] = 2;
                          foo.__val[1] = 3;
                      }
                  }.format(fullHeaderFileName));


        const fullInputFileName = buildPath(testPath, inputFileName);
        const fullOutputFileName = buildPath(testPath, "foo.d");
        preprocess!File(fullInputFileName, fullOutputFileName);

        const result = execute(["dmd", "-o-", "-c", fullOutputFileName]);
        enforce(result.status == 0, "Could not build the resulting file:\n" ~ result.output);
    }
}
