import unit_threaded;

int main(string[] args) {
    return args.runTests!(

        // in-file
        "include.runtime",
        "include.translation",
        "include.expansion",

        // unit tests
        "ut.translation.field",
        "ut.translation.function_",

        // integration tests
        "it.compile.preprocessor",
        "it.compile.struct_",
        "it.compile.union_",
        "it.compile.array",
        "it.run.struct_",
    );
}
