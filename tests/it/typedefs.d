module it.typedefs;

import unit_threaded;
import include.runtime;


@ShouldFail
@("fsid_t")
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
                      #define __FSID_T_TYPE struct { int __val[2]; }
                      typedef  __FSID_T_TYPE __fsid_t;
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

// the issue here is that header.h includes system.h
// when dstep uses the TypedefIndex in Context, it checks that
// the file is the same.
// i.e. if header.h itself had the definitions this would work fine,
// but if it's an different file it falls apart
// Translator.translate -> translateRecord -> translateRecordDef ->
// Context.translateTagSpelling -> TypeDefIndex.typedefParent
@ShouldFail
@("fd_set")
@safe unittest {

    import std.stdio: File;
    import std.process: execute;
    import std.path: buildPath;
    import std.format: format;
    import std.exception: enforce;

    with(immutable Sandbox()) {

        writeFile("system.h",
                  q{
                      #define __FD_SETSIZE 1024
                      typedef long int __fd_mask;
                      #define __NFDBITS (8 * (int) sizeof (__fd_mask))

                      typedef struct
                      {
                       #ifdef __USE_XOPEN
                          __fd_mask fds_bits[__FD_SETSIZE / __NFDBITS];
                       # define __FDS_BITS(set) ((set)->fds_bits)
                       #else
                          __fd_mask __fds_bits[__FD_SETSIZE / __NFDBITS];
                       # define __FDS_BITS(set) ((set)->__fds_bits)
                       #endif
                      } fd_set;
                  });


        const headerFileName = "header.h";

        writeFile(headerFileName,
                  q{
                      #include "system.h"
                  });


        const fullHeaderFileName = buildPath(testPath, headerFileName);
        const inputFileName = "foo.d_";
        writeFile(inputFileName,
                  q{
                      #include "%s"
                      void func() {
                          fd_set foo;
                          foo.__fds_bits[0] = 5;
                      }
                  }.format(fullHeaderFileName));


        const fullInputFileName = buildPath(testPath, inputFileName);
        const fullOutputFileName = buildPath(testPath, "foo.d");
        preprocess!File(fullInputFileName, fullOutputFileName);

        const result = execute(["dmd", "-o-", "-c", fullOutputFileName]);
        enforce(result.status == 0, "Could not build the resulting file:\n" ~ result.output);
    }
}
