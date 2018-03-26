module it.compile.union_;

import it.compile;

@("__SIZEOF_PTHREAD_ATTR_T")
@safe unittest {
    with(immutable IncludeSandbox()) {

        writeFile("header.h",
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


        writeFile("foo.d_",
                  q{
                      #include "%s"
                      void func() {
                          union_pthread_attr_t attr;
                          attr.__size[0] = 42;
                      }
                  }.format(inSandboxPath("header.h")));


        preprocess("foo.d_", "foo.d");
        shouldCompile("foo.d");
    }
}
