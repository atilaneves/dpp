import unit_threaded;

int main(string[] args) {
    return args.runTests!(
        "integration.clang",
        "integration.preprocessor",
    );
}
