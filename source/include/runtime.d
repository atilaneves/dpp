module include.runtime;

version(unittest) {
    import unit_threaded;
    import include.test_util;
}

void run(string[] args) {
    import std.stdio: File;
    const inputFileName = args[1];
    const outputFileName = args[2];
    return preprocess!File(inputFileName, outputFileName);
}

void preprocess(File)(in string inputFileName, in string outputFileName) {

    import include.translation: translate;
    import std.algorithm: map;

    auto outputFile = File(outputFileName, "w");

    outputFile.writeln("import core.stdc.config;");
    outputFile.writeln("struct __FSID_T_TYPE { int[2] __val; }");
    outputFile.writeln("alias __U32_TYPE = uint;");
    outputFile.writeln("alias __S32_TYPE = int;");
    outputFile.writeln("alias __UQUAD_TYPE = uint;");
    outputFile.writeln("alias __SQUAD_TYPE = int;");
    outputFile.writeln("alias __UWORD_TYPE = ushort;");
    outputFile.writeln("alias __SWORD_TYPE = short;");
    outputFile.writeln("version(X86) {");
    outputFile.writeln("    alias __SLONGWORD_TYPE = int;");
    outputFile.writeln("    alias __ULONGWORD_TYPE = uint;");
    outputFile.writeln("} else version(X86_64) {");
    outputFile.writeln("    alias __SLONGWORD_TYPE = long;");
    outputFile.writeln("    alias __ULONGWORD_TYPE = ulong;");
    outputFile.writeln("}");


    foreach(line; File(inputFileName).byLine.map!(a => cast(string)a)) {
        outputFile.writeln(line.translate);
    }
}
