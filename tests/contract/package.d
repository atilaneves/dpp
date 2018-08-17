/**
   Contract tests for libclang.
   https://martinfowler.com/bliki/ContractTest.html
 */
module contract;

public import unit_threaded;
public import clang: Cursor, Type;


struct C {
    string value;
}

struct Cpp {
    string value;
}

auto parse(T)(in T code) {
    import unit_threaded.integration: Sandbox;
    import clang: parse_ = parse;

    enum isCpp = is(T == Cpp);

    with(immutable Sandbox()) {
        const extension = isCpp ? "cpp" : "c";
        const fileName = "code." ~ extension;
        writeFile(fileName, code.value);

        auto tu = parse_(inSandboxPath(fileName)).cursor;
        printChildren(tu);
        return tu;
    }
}


void printChildren(T)(auto ref T cursorOrTU) {
    import unit_threaded.io: writelnUt;
    import std.algorithm: map;
    import std.array: join;
    import std.conv: text;

    writelnUt("\n", cursorOrTU, " children:\n[\n", cursorOrTU.children.map!(a => text("    ", a)).join(",\n"));
    writelnUt("]\n");
}
