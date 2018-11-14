import unit_threaded.runner.runner;

version(dpp2) {
    mixin runTestsMain!(
        "ut.type.primitives",
        "ut.type.array",
        "ut.type.pointer",
    );
} else {
    mixin runTestsMain!(
        // in-file
        "dpp.runtime",
        "dpp.translation",
        "dpp.expansion",

        // unit tests
        "ut.old.type",

        // contract tests
        "contract.array",
        "contract.templates",
        "contract.namespace",
        "contract.macro_",
        "contract.constexpr",
        "contract.typedef_",
        "contract.operators",
        "contract.member",

        "it.issues",

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
    );
}
