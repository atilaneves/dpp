module it.old.typedefs;

import it.compile;


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

    with(immutable IncludeSandbox()) {

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


        writeFile("header.h",
                  q{
                      #include "system.h"
                  });

        const inputFileName = "foo.d_";
        writeFile("foo.d_",
                  q{
                      #include "%s"
                      void func() {
                          fd_set foo;
                          foo.__fds_bits[0] = 5;
                      }
                  }.format(inSandboxPath("header.h")));


        preprocess!File(inSandboxPath("foo.d_"), inSandboxPath("foo.d"));
        shouldCompile("foo.d");
    }
}
