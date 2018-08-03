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

auto parse(in C code) {
    import unit_threaded.integration: Sandbox;
    import clang: parse_ = parse;

    with(immutable Sandbox()) {
        const fileName = "code.c";
        writeFile(fileName, code.value);
        return parse_(inSandboxPath(fileName)).cursor;
    }
}
