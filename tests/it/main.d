import unit_threaded.runner;


mixin runTestsMain!(
    "it.issues",
    "it.expansion",

    // C tests
    "it.c.compile.preprocessor",
    "it.c.compile.struct_",
    "it.c.compile.union_",
    "it.c.compile.array",
    "it.c.compile.enum_",
    "it.c.compile.typedef_",
    "it.c.compile.function_",
    "it.c.compile.projects",
    "it.c.compile.runtime_args",
    "it.c.compile.collision",
    "it.c.compile.extensions",
    "it.c.run.struct_",
    "it.c.run.c",

    // tests copied from dstep
    "it.c.dstep.ut",
    "it.c.dstep.functional",
    "it.c.dstep.issues",

    // C++ tests
    "it.cpp.run",
    "it.cpp.function_",
    "it.cpp.class_",
    "it.cpp.templates",
    "it.cpp.misc",
    "it.cpp.opaque",
);
