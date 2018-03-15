module it.old.preprocessor;

import it;
import include.runtime;
import std.stdio: File;
import std.format: format;


@ShouldFail
@("__SIZEOF_PTHREAD_ATTR_T")
@safe unittest {

    import std.process: execute;
    import std.path: buildPath;
    import std.exception: enforce;

    with(immutable Sandbox()) {

        const headerFileName = "header.h";

        writeFile(headerFileName,
                  q{
                      #ifdef __x86_64__
                      #  if __WORDSIZE == 64
                      #    define __SIZEOF_PTHREAD_ATTR_T 56
                      #  else
                      #    define __SIZEOF_PTHREAD_ATTR_T 32
                      #  endif
                      #else
                      #  define __SIZEOF_PTHREAD_ATTR_T 36
                      #endif

                      union pthread_attr_t
                      {
                          char __size[__SIZEOF_PTHREAD_ATTR_T];
                          long int __align;
                      };
                  });


        const fullHeaderFileName = buildPath(testPath, headerFileName);
        const inputFileName = "foo.d_";
        writeFile(inputFileName,
                  q{
                      #include "%s"
                      void func() {
                          pthread_attr_t attr;
                          attr.__size[0] = 42;
                      }
                  }.format(fullHeaderFileName));


        const fullInputFileName = buildPath(testPath, inputFileName);
        const fullOutputFileName = buildPath(testPath, "foo.d");
        preprocess!File(fullInputFileName, fullOutputFileName);

        const result = execute(["dmd", "-o-", "-c", fullOutputFileName]);
        enforce(result.status == 0, "Could not build the resulting file:\n" ~ result.output);
    }
}
