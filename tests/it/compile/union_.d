module it.compile.union_;

import it;

@("__SIZEOF_PTHREAD_ATTR_T")
@safe unittest {
    shouldCompile(
        C(
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
            }
        ),

        D(
            q{
                pthread_attr_t attr;
                attr.__size[0] = 42;
            }
        )
    );
}
