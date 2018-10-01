module dpp.runtime.namespace;

/**
   Uses a template mixin hack to "reopen" C++ namespace declarations in D
 */
struct Namespace {
    static struct Symbol {
        string namespace;
        string name;
    }

    enum indentationSpaces = "    ";
    private int _index;
    private string[] _nestedNamespaces;
    private Symbol[] _symbols;
    private string _mixinName;

    string[] push(in string name) @safe pure {
        import std.conv: text;
        string[] lines;

        if(_nestedNamespaces.length == 0) {
            _mixinName = text("_CppNamespace", _index);
            lines ~= text("mixin template ", _mixinName, "() {");
        }

        lines ~= indentationSpaces ~ text("extern(C++, ", name, ") {");
        _nestedNamespaces ~= name;

        return lines;
    }

    string[] pop(ref bool[string] globalAliases) @safe pure {

        _nestedNamespaces = _nestedNamespaces[0 .. $-1];
        auto lines = [indentationSpaces ~ "}"];

        if(_nestedNamespaces.length == 0) {
            lines ~= finish(globalAliases);
        }

        return lines;
    }

    void addSymbol(in string symbol) @safe pure {
        import std.array: join;
        if(symbol != "")
            _symbols ~= Symbol(_nestedNamespaces.join("."), symbol);
    }

    private string[] finish(ref bool[string] globalAliases) @safe pure {
        import std.conv: text;
        import std.algorithm: map, uniq, filter;
        import std.array: array;

        auto lines = ["}", ""];

        const varName = text("_cppNamespace_", _index);
        lines ~= text("mixin ", _mixinName, "!() ", varName, ";");

        string aliasText(in Symbol s) {
            return text("alias ", s.name, " = ", varName, ".", s.namespace, ".", s.name, `;`);
        }

        string staticIf(in Symbol s) {
            // FIXME - no idea what's going on
            if(s.name == "random_access_iterator_tag") return "";
            return `static if(is(typeof({ ` ~ aliasText(s) ~ ` }))) `;
        }

        lines ~= _symbols
            .uniq!((a, b) => a.name == b.name)
            .filter!(a => a.name !in globalAliases)
            .map!(s => staticIf(s) ~ aliasText(s) ~ `;`)
            .array
            ;

        foreach(symbol; _symbols) globalAliases[symbol.name] = true;

        reset;

        return lines;
    }

    private void reset() @safe pure {
        _mixinName = "";
        _index++;
        _symbols = [];
    }
}
