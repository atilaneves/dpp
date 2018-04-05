import unit_threaded;

int main(string[] args) {
    return args.runTests!(

        // in-file
        "dpp.runtime",
        "dpp.cursor",
        "dpp.expansion",

        // unit tests
        "ut.type",

        // integration tests with code that should compile
        "it.compile.preprocessor",
        "it.compile.struct_",
        "it.compile.union_",
        "it.compile.array",
        "it.compile.enum_",
        "it.compile.typedef_",
        "it.compile.function_",
        "it.compile.projects",
        "it.compile.runtime_args",

        "it.issues",

        // tests copied from dstep
        "it.dstep.ut",
        "it.dstep.functional",

        // integration tests with code that should run
        "it.run.struct_",
        "it.run.c",
        "it.run.cpp",
    );
}
