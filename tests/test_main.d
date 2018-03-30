import unit_threaded;

int main(string[] args) {
    return args.runTests!(

        // in-file
        "include.runtime",
        "include.translation",
        "include.expansion",

        // unit tests
        "ut.translation.field",
        "ut.translation.type",
        "ut.translation.enum_",

        // integration tests with code that should compile
        "it.compile.preprocessor",
        "it.compile.struct_",
        "it.compile.union_",
        "it.compile.array",
        "it.compile.enum_",
        "it.compile.typedef_",
        "it.compile.function_",
        "it.compile.projects",

        // tests copied from dstep
        "it.dstep.ut",
        "it.dstep.functional",

        // integration tests with code that should run
        "it.run.struct_",
        "it.run.cpp",
    );
}
