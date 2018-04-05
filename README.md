include
========

| [![Build Status](https://travis-ci.org/atilaneves/include.png?branch=master)](https://travis-ci.org/atilaneves/include) | [![Coverage](https://codecov.io/gh/atilaneves/include/branch/master/graph/badge.svg)](https://codecov.io/gh/atilaneves/include) |


Goal
----

To directly `#include` C and C++ headers in (D)[https://dlang.org] files and have the same semantics and ease-of-use
as if the file had been `#included` from C or C++ themselves. Warts and all, meaning that C `enum` declarations
will pollute the global namespace, just as it does "back home".

Limitations
-----------

* It currently only supports C features, but C++ is planned, templates and all.
* Using it on a C++ header will "work" if it's basically technically C, with `extern(C++)` instead of `extern(C)`
* Packed structs are not supported yet.
* C99 bitfields are not supported yet.

This is alpha sofware. It has however produced programs that compile that #included several "real-life" C headers:

* nanomsg/nn.h, nanomsg/pubsub.h
* curl/curl.h
* stdio.h, stdlib.h
* pthread.h
* xlsxwriter.h
* libvirt/libvirt.h, libvirt/virterror.h
* libzfs
* openssl/ssl.h
* imapfilter.h
* libetpan/libetpan.h

Compilation however doesn't guarantee they work as expected and YMMV. Please consult the examples.


Command-line arguments
----------------------

It is likely that the header or headers need `-I` flags to indicate paths to be searched,
both by this executable and by libclang itself.

Use `-h` or `--help` to learn more.


Details
-------

`include` is an executable that has as input a D file with C `#include` preprocessor directives and outputs
a valid D file that can be compiled. The original can't be compiled since D has no integrated preprocessor.

The only supported preprocessor directive is `#include`.

The input file may also use C preprocessor macros defined in the file(s) it q`#include`s, just as a C/C++
program would. It may not, however, define macros of its own.

`include` goes through the input file line-by-line, and upon encountering an `#include` directive, parses
the file to be included with libclang, loops over the definitions of data structures and functions
therein and expands in-place the relevant D translations. e.g. if a header contains:

```c
uint16_t foo(uin32_t a);
```

The output file will contain:

```d
ushort foo(ushort a);
```

include will also enclose each one of these original `#include` directives with either
`extern(C) {}` or `extern(C++) {}` depending on the header file name and/or command-line options.

As part of expanding the `#include`, and as well as translating declarations, include will also
insert text to define macros originally defined in the `#include`d translation unit so that these
macros can be used by the D program. The reason for this is that nearly every non-trivial
C API requires the preprocessor to use properly. It is possible to mimic this usage in D
with enums and CTFE, but the result is not guaranteed to be the same. The only way to use a
C or C++ API as it was intended is by leveraging the preprocessor.

As a final pass before writing the output file, include will run the C preprocessor on the
intermediary result of expanding all the `#include` directives so that any used macros are
expanded, and the result is a D file that can "natively" call into a C/C++ API by
`#include`ing the appropriate header(s).

Example
-------

```c
// foo.h
#ifndef FOO_H
#define FOO_H

#define FOO_ID(x) (x*3)

int twice(int i);

#endif
```

```d
// foo.dpp
#include "foo.h"
void main() {
    import std.stdio;
    writeln(twice(FOO_ID(5)));
}
```

At the shell:

```
$ ./include foo.dpp foo.d
$ dmd foo.d
$ ./foo
$ 30
```

Translation notes
----------------

### Names of structs, enums and unions

C has a different namespace for the aforementioned user-defined types. As such, this is legal C:

```c
struct foo { int i; };
extern int foo;
```

The D translations just use the short name for these aggregates, and if there is a name collision
with a variable or function, the latter two get renamed and have a `pragma(mangle)` added to
avoid linker failures:


```d
struct foo { int i; }
pragma(mangle, "foo") extern __gshared int foo_;
```

### Functions or variables with a name that is a D keyword

Similary to name collisions with aggregates, they get an underscore
appended and a `pragma(mangle)` added so they link:

```c
void debug(const char* msg);
```

Becomes:


```d
pragma(mangle, "debug")
void debug_(const(char)*);
```


### enum

For convenience, this declaration:

```c
enum Enum { foo, bar, baz }
```

Will generate this translation:

```d
enum Enum { foo, bar, baz }
enum foo = Enum.foo;
enum bar = Enum.bar;
enum baz = Enum.baz;
```

This is to mimic C semantics with regards to the global namespace whilst also allowing
one to, say, reflect on the enum type.
