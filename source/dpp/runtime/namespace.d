module dpp.runtime.namespace;


struct Namespace {

    string[] push(in string name) @safe pure {
        return [
            `extern(C++, "` ~ name ~ `")`,
            `{`,
        ];
    }

    string[] pop(ref bool[string] globalAliases) @safe pure {
        return [`}`];
    }

    void addSymbol(in string symbol) @safe pure {

    }
}
