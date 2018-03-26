/**
   Integration tests that stem from failues in real-life C projects
 */
module it.compile.projects;

import it.compile;

@("nn_get_statistic")
@safe unittest {
    with(const IncludeSandbox()) {

        // the original uses regular uint64_t, let's beat any special cases
        // defining our own
        writeFile("hdr.h",
                  q{
                      typedef unsigned long int __my_uint64_t;
                      typedef __my_uint64_t my_uint64_t;
                      my_uint64_t nn_get_statistic (int s, int stat);
                  });

        writeFile("app.dpp",
                  q{
                      #include "%s"
                      void main() {
                          int s;
                          int stat;
                          my_uint64_t ret = nn_get_statistic(s, stat);
                      }
                  }.format(inSandboxPath("hdr.h")));

        preprocess("app.dpp", "app.d");
        shouldCompile("app.d");
    }
}

@("__io_read_fn")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
                  q{
                      typedef long long __ssize_t;
                      typedef __ssize_t __io_read_fn (void *__cookie, char *__buf, size_t __nbytes);
                  });

        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          void* cookie;
                          char[1024] buf;
                          __ssize_t ret = __io_read_fn.init(cookie, buf.ptr, buf.length);
                      }
                  });

        shouldCompile("app.d", "hdr.d");
    }
}

@("timer_t")
@safe unittest {
    with(const IncludeSandbox()) {

        // the original uses regular uint64_t, let's beat any special cases
        // defining our own
        writeFile("hdr.h",
                  q{
                      #define __TIMER_T_TYPE void *
                      typedef __TIMER_T_TYPE __timer_t;
                  });

        writeFile("app.dpp",
                  q{
                      #include "%s"
                      void main() {
                          __timer_t timer = null;
                      }
                  }.format(inSandboxPath("hdr.h")));

        preprocess("app.dpp", "app.d");
        shouldCompile( "app.d");
    }
}


@("curl_multi_wait")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef enum { CURLM_OK } CURLMcode;
                   typedef int curl_socket_t;

                   struct curl_waitfd {
                       curl_socket_t fd;
                       short events;
                       short revents; /* not supported yet */
                   };

                   typedef struct { int dummy; } CURLM;
                   CURLMcode curl_multi_wait(CURLM *multi_handle,
                                             struct curl_waitfd extra_fds[],
                                             unsigned int extra_nfds,
                                             int timeout_ms,
                                             int *ret);
                  });

        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          CURLM handle;
                          struct_curl_waitfd[] extra_fds;
                          int ret;
                          CURLMcode code = curl_multi_wait(&handle, extra_fds.ptr, 42u, 33, &ret);
                      }
                  });

        shouldCompile("app.d", "hdr.d");
    }

}

@("__sigset_t")
@safe unittest {
    with(const IncludeSandbox()) {

        // the original uses regular uint64_t, let's beat any special cases
        // defining our own
        writeFile("hdr.h",
                  q{
                      #define _SIGSET_NWORDS (1024 / (8 * sizeof (unsigned long int)))
                      typedef struct
                      {
                          unsigned long int __val[_SIGSET_NWORDS];
                      } __sigset_t;
                  });

        writeFile("app.dpp",
                  q{
                      #include "%s"
                      void main() {
                          auto s = __sigset_t();
                          ++s.__val[7];
                      }
                  }.format(inSandboxPath("hdr.h")));

        preprocess("app.dpp", "app.d");
        shouldCompile( "app.d");
    }
}


@("_IO_flockfile")
@safe unittest {
    with(const IncludeSandbox()) {
        writeFile("hdr.h",
                  q{
                   struct _IO_FILE { int dummy; };
                   extern void _IO_flockfile (struct _IO_FILE *);
                   #define _IO_flockfile(_fp)
                  });

        writeFile("app.dpp",
                  q{
                      #include "%s"
                      void main() {
                          struct__IO_FILE file;
                          _IO_flockfile(&file);
                      }
                  }.format(inSandboxPath("hdr.h")));

        preprocess("app.dpp", "app.d");
        shouldCompile("app.d");
    }
}

@("struct with union")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   struct Struct {
                       union {
                           void *ptr;
                           int i;
                       } data;
                   };
                   typedef struct Struct Struct;
                  });

        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          struct_Struct s;
                          s.data.ptr = null;
                          s.data.i = 42;
                      }
                  });

        shouldCompile("app.d", "hdr.d");
    }
}

@("const char* const")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   struct Struct {
                       const char * const *protocols;
                   };
                   typedef struct Struct Struct;
                  });

        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          Struct s;
                          static assert(is(typeof(s.protocols) == const(char*)*),
                                        "Expected const(char*)*, not " ~
                                        typeof(s.protocols).stringof);
                      }
                  });

        shouldCompile("app.d", "hdr.d");
    }
}

@("forward declaration")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   struct Struct;
                   void fun(struct Struct* s);
                   struct Struct* make_struct(void);
                  });

        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          struct_Struct* s = make_struct();
                          fun(s);
                      }
                  });

        shouldCompile("app.d", "hdr.d");
    }
}


@("restrict")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   struct FILE { int dummy; }
                   extern FILE *fopen(const char *restrict filename,
                                      const char *restrict modes);
               });

        writeFile("app.d",
                  q{
                      import hdr;
                      import std.string;
                      void main() {
                          fopen("foo.txt".toStringz, "w".toStringz);
                      }
                  });

        shouldCompile("app.d", "hdr.d");
    }
}


@("return type typedefd enum")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef struct { int dummy; } CURL;

                   typedef enum {
                       CURLIOE_OK,            /* I/O operation successful */
                   } curlioerr;

                   typedef curlioerr (*curl_ioctl_callback)(CURL *handle,
                                                            int cmd,
                                                            void *clientp);
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          CURL handle;
                          auto func = curl_ioctl_callback.init;
                          curlioerr err = func(&handle, 42, null);
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}


@("curl_slist")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   struct curl_httppost {
                       struct curl_slist *contentheader;
                   };
                   struct curl_slist {
                       char *data;
                       struct curl_slist *next;
                   };
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          struct_curl_httppost p;
                          p.contentheader.data = null;
                          p.contentheader.next = null;
                          struct_curl_slist l;
                          l.data = null;
                          l.next = null;
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}

@("name collision between struct and var")
@safe unittest {
    with(const IncludeSandbox()) {
        writeFile("hdr.h",
                  q{
                      struct timezone {
                          int tz_minuteswest;
                          int tz_dsttime;
                      };
                      extern long int timezone;
                  });
        writeFile("app.dpp",
                  q{
                      #include "%s"
                      void main() {
                          timezone = 42;
                          auto s = struct_timezone(33, 77);
                      }
                  }.format(inSandboxPath("hdr.h")));
        preprocess("app.dpp", "app.d");
        shouldCompile("app.d");
    }
}

@("use int for enum parameter")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef enum {
                       foo,
                       bar,
                   } Enum;
                   void func(Enum e);
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          func(Enum.bar);
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}

@("pthread struct")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef struct {
                       void (*routine)(void*);
                   } Struct;
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      extern(C) void foo(void*) {}

                      void main() {
                          Struct s;
                          s.routine = &foo;
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}


@ShouldFail("Can only alias once")
@("multiple typedefs")
@safe unittest {
    with(const IncludeSandbox()) {
        expand(Out("hdr.d"), In("hdr.h"),
               q{
                   typedef long time_t;
                   typedef long time_t;
               });
        writeFile("app.d",
                  q{
                      import hdr;
                      void main() {
                          time_t var = 42;
                      }
                  });
        shouldCompile("app.d", "hdr.d");
    }
}
