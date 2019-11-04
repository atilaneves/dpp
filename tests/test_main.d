import unit_threaded.runner.runner;

version(dpp2) {
    mixin runTestsMain!(
        // unit tests

        "ut.translation.type.primitives",
        "ut.translation.type.array",
        "ut.translation.type.pointer",

        "ut.translation.node.structs",

        "ut.transform.clang",
        "ut.transform.cursor",
        "ut.transform.type",

        // integration tests
        "it.c.compile.struct_",
    );
} else {
    mixin runTestsMain!(
        // in-file
        "dpp.runtime",
        "dpp.translation",
        "dpp.expansion",

        // unit tests
        "ut.old.type",
        "ut.expansion",

        // contract tests
        "contract.array",
        "contract.templates",
        "contract.namespace",
        "contract.macro_",
        "contract.constexpr",
        "contract.typedef_",
        "contract.operators",
        "contract.member",
        "contract.aggregates",
        "contract.inheritance",
        "contract.issues",
        "contract.methods",
        "contract.functions",

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
}
