module it.c.dstep.issues;

import it;

@("")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{

            }
        ),
        D(
            q{
            }
        ),
    );
}


@("8")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            `
                #include <stdint.h>

                typedef struct rd_kafka {
                	int dummy;
                } rd_kafka_t;

                typedef struct rd_kafka_topic {
                	int dummy;
                } rd_kafka_topic_t;

                typedef struct rd_kafka_metadata {
                        int         broker_cnt;     /* Number of brokers in 'brokers' */
                        struct rd_kafka_metadata_broker *brokers;  /* Brokers */

                        int         topic_cnt;      /* Number of topics in 'topics' */
                        struct rd_kafka_metadata_topic *topics;    /* Topics */

                        int32_t     orig_broker_id; /* Broker originating this metadata */
                        char       *orig_broker_name; /* Name of originating broker */
                } rd_kafka_metadata_t;

                rd_kafka_metadata (rd_kafka_t *rk, int all_topics,
                                   rd_kafka_topic_t *only_rkt,
                                   const struct rd_kafka_metadata **metadatap,
                                   int timeout_ms);
            `
        ),
        D(
            q{
                rd_kafka_t kafka; kafka.dummy = 42;
                rd_kafka_topic_t topic; topic.dummy = 42;
                const(rd_kafka_metadata) *meta;
                rd_kafka_metadata_(&kafka, 42, &topic, &meta, 77);
            }
        ),
    );
}


@("10")
@Tags("dstep_issues")
@safe unittest
{
    shouldCompile(
        C(
            q{
                struct info {
                    long remote_ip;
                    int remote_port;
                    int is_ssl;
                    void *user_data;

                    struct mg_header {
                        const char *name;
                        const char *value;
                    } headers[64];
                };
            }
        ),
        D(
            q{
                info inf;

                inf.remote_ip = 42L;
                inf.remote_port = 42;
                inf.is_ssl = 33;
                inf.user_data = null;

                inf.headers[63].name = "name".ptr;
                inf.headers[63].value = "value".ptr;

                static assert( __traits(compiles, () => inf.headers[63].value));
                static assert(!__traits(compiles, () => inf.headers[64].value));
            }
        ),
    );
}


@("20")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            `
                #define X (1)
                #define Y ((float)-X)
                #define f(x, b) ((a) + (b))
                #define foo 1
            `
        ),
        D(
            q{
                static assert(X == 1);
                static assert(Y == -1.0);
                enum a = 2;
                static assert(f(7, 3) == 5);
                static assert(foo == 1);
            }
        ),
    );
}

@("38")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                void foo();
                void bar(const char* fmt, ...);
                void baz(void);
            }
        ),
        D(
            q{
                foo();
                bar("foo".ptr, 1, 2, 3.0, "foo".ptr);
                baz();
            }
        ),
    );
}

@("46")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            `
                typedef unsigned char __u8;
                typedef unsigned int __u32;
                typedef __signed__ long __s64;
                typedef unsigned long __u64;

                struct stats_t {
                    __u8 scale;
                    union {
                        __u64 uvalue;
                        __s64 svalue;
                    };
                } __attribute__ ((packed));


                #define MAX_STATS   4

                struct fe_stats_t {
                    __u8 len;
                    struct stats_t stat[MAX_STATS];
                } __attribute__ ((packed));

                struct property_t {
                    __u32 cmd;
                    __u32 reserved[3];
                    union {
                        __u32 data;
                        struct fe_stats_t st;
                        struct {
                            __u8 data[32];
                            __u32 len;
                            __u32 reserved1[3];
                            void *reserved2;
                        } buffer;
                    } u;
                    int result;
                } __attribute__ ((packed));
            `
        ),
        D(
            q{
            }
        ),
    );
}

@("85")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            `
                #include <stddef.h>
                int complex_forward (const double data[], const size_t stride, const size_t n, double result[]);
            `
        ),
        D(
            q{
                double* data;
                size_t stride;
                size_t n;
                double* result;
                int ret = complex_forward(data, stride, n, result);
            }
        ),
    );
}


@("98")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                struct timeval { };
                void term_await_started(const struct timeval *timeout);
            }
        ),
        D(
            q{
                timeval timeout;
                term_await_started(&timeout);
            }
        ),
    );
}


@("102")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct _ProtobufCMethodDescriptor ProtobufCMethodDescriptor;

                struct _ProtobufCMethodDescriptor
                {
                    const char *name;
                    const ProtobufCMethodDescriptor *input;
                    const ProtobufCMethodDescriptor *output;
                };
            }
        ),
        D(
            q{
                ProtobufCMethodDescriptor desc;
                desc.name = "name".ptr;
                desc.input = &desc;
                desc.output = &desc;
            }
        ),
    );
}


@("106")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                float _Complex foo;
                double _Complex bar;
                long double _Complex baz;
            }
        ),
        D(
            q{

            }
        ),
    );
}

@("107")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct foo foo;
            }
        ),
        D(
            q{
                foo* f = null;
            }
        ),
    );
}

@("114")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct _Foo_List {
                    void *data;
                    struct _Foo_List *next;
                } Foo_List;
            }
        ),
        D(
            q{
                Foo_List list;
                list.data = null;
                list.next = &list;
            }
        ),
    );
}

@("116")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                int foo(void);

                typedef int (*Fun0)(void);
                typedef int (*Fun1)(int (*param)(void));

                struct Foo {
                    int (*bar)(void);
                };
            }
        ),
        D(
            q{
                int f0 = Fun0.init();
                int f1 = Fun1.init(&foo);
                Foo foo;
                int res = foo.bar();
            }
        ),
    );
}


@("123")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            `
                #include <limits.h>
                #define TEST INT_MAX
            `
        ),
        D(
            q{
                static assert(TEST == INT_MAX);
            }
        ),
    );
}

@("137")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct {
                    struct DB_vfs_s *vfs;
                } DB_FILE;

                typedef int DB_playItem_t;

                typedef struct DB_plugin_action_s {
                    const char *title;
                    const char *name;
                    unsigned flags;
                } DB_plugin_action_t;

                typedef struct DB_vfs_s {
                    const char **(*get_schemes) (void);
                    int (*is_streaming) (void); // return 1 if the plugin streaming data
                    void (*abort) (DB_FILE *stream);
                    const char * (*get_content_type) (DB_FILE *stream);
                    void (*set_track) (DB_FILE *f, DB_playItem_t *it);
                } DB_vfs_t;
            }
        ),
        D(
            q{
                DB_FILE dbFile;
                dbFile.vfs = null;
                DB_plugin_action_t action;
                action.title = "title".ptr;
                action.name = "name".ptr;
                action.flags = 0u;

                DB_vfs_t vfs;
                const(char)** schemes = vfs.get_schemes();
                int isStreaming = vfs.is_streaming();
                vfs.abort(&dbFile);
                const(char)* contentType = vfs.get_content_type(&dbFile);
                DB_playItem_t playItem;
                vfs.set_track(&dbFile, &playItem);
            }
        ),
    );
}

@("138")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                extern const unsigned fe_bandwidth_name[8];
                extern const unsigned fe_bandwidth_name[8];
            }
        ),
        D(
            q{
                uint i = fe_bandwidth_name[7];
            }
        ),
    );
}

@("140")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef enum fe_delivery_system {
                    SYS_UNDEFINED,
                    SYS_DVBC_ANNEX_A,
                } fe_delivery_system_t;
            }
        ),
        D(
            q{
                const undef = fe_delivery_system_t.SYS_UNDEFINED;
            }
        ),
    );
}


@("141")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            `
                #define _IOC_NRSHIFT	0
                #define _IOC_TYPESHIFT	1
                #define _IOC_SIZESHIFT	2
                #define _IOC_DIRSHIFT	3

                #define _IOC_NONE	0U
                #define _IOC_READ	2U

                #define _IOC(dir,type,nr,size) \
                	(((dir)  << _IOC_DIRSHIFT) | \
                	 ((type) << _IOC_TYPESHIFT) | \
                	 ((nr)   << _IOC_NRSHIFT) | \
                	 ((size) << _IOC_SIZESHIFT))

                #define _IOC_TYPECHECK(t) (sizeof(t))

                #define _IO(type,nr)		_IOC(_IOC_NONE,(type),(nr),0)
                #define _IOR(type,nr,size)	_IOC(_IOC_READ,(type),(nr),(_IOC_TYPECHECK(size)))

                typedef struct { } foo_status_t;
                typedef unsigned int __u32;
                typedef unsigned short __u16;

                #define FE_READ_STATUS _IOR('o', 69, foo_status_t)
                #define FE_READ_BER _IOR('o', 70, __u32)
                #define FE_READ_SIGNAL_STRENGTH _IOR('o', 71, __u16)
                #define FE_READ_SNR _IOR('o', 72, __u16)
                #define FE_READ_UNCORRECTED_BLOCKS _IOR('o', 73, __u32)
            `
        ),
        D(
            q{
                static assert(_IOC_NRSHIFT == 0);
                static assert(_IOC_TYPESHIFT == 1);
                static assert(_IOC(4, 5, 6, 7) == 62);
                static assert(_IOC_TYPECHECK(int) == 4);
                static assert(_IO(4, 5) == 13);
                static assert(_IOR(4, 5, 6) == 29);
                static assert(FE_READ_STATUS == 223);
                static assert(FE_READ_BER == 222);
                static assert(FE_READ_SIGNAL_STRENGTH == 223);
                static assert(FE_READ_SNR == 222);
                static assert(FE_READ_UNCORRECTED_BLOCKS == 223);
            }
        ),
    );
}

@("160")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            q{
                typedef struct { } CXFile;
                typedef struct { } CXSourceLocation;
                typedef struct { } CXClientData;

                typedef void (*CXInclusionVisitor)(CXFile included_file,
                                                   CXSourceLocation* inclusion_stack,
                                                   unsigned include_len,
                                                   CXClientData client_data);
            }
        ),
        D(
            q{
                CXFile file;
                CXSourceLocation location;
                CXClientData data;
                CXInclusionVisitor.init(file, &location, 42u, data);
            }
        ),
    );
}

@("166.0")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            `
                #define __FSID_T_TYPE struct { int __val[2]; }
                typedef  __FSID_T_TYPE __fsid_t;
                typedef __fsid_t fsid_t;
            `
        ),
        D(
            q{
                static assert(fsid_t.__val.length == 2);
            }
        ),
    );
}

@("166.1")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            `
                #define FOO 2
                #define __FSID_T_TYPE struct { int __val[FOO]; }
                typedef  __FSID_T_TYPE __fsid_t;
                typedef __fsid_t fsid_t;
            `
        ),
        D(
            q{
                static assert(fsid_t.__val.length == 2);
            }
        ),
    );
}


@("166.2")
@Tags("dstep_issues")
@safe unittest {
    shouldCompile(
        C(
            `
                #define FOO 2
                #define BAR FOO
                #define __FSID_T_TYPE struct { int __val[BAR]; }
                typedef  __FSID_T_TYPE __fsid_t;
                typedef __fsid_t fsid_t;
            `
        ),
        D(
            q{
                static assert(fsid_t.__val.length == 2);
            }
        ),
    );
}
