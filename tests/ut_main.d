import unit_threaded;

int main(string[] args) {
    return args.runTests!(

        // in-file
        "include.runtime",
        "include.translation",

        // unit tests

        // integration tests
        "it.preprocessor",
        "it.typedefs",
        "it.translation.struct_",
    );
}
