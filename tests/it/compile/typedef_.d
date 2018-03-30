module it.compile.typedef_;

import it.compile;

@("unsigned char")
unittest {
    shouldCompile(
        C(
            q{
                typedef unsigned char __u_char;
            }
        ),
        D(
            q{
                static assert(__u_char.sizeof == 1);
            }
        )
    );
}

@("const char*")
unittest {
    shouldCompile(
        C(
            q{
                typedef const char* mystring;
            }
        ),
        D(
            q{
                const(char)[128] buffer;
            }
        )
    );
}
