/**
   Type translations
 */
module include.translation.type;

import include.from;

string translate(in from!"clang".Type type) @safe pure {
    import clang: Type;
    import std.conv: text;

    switch(type.kind) with(Type.Kind) {
        default:         assert(false, text("Type kind ", type.kind, " not supported"));
        case Int:        return "int";
        case Double:     return "double";
        case Elaborated: return type.spelling.cleanType;
    }
}

string cleanType(in string type) @safe pure {
    import std.algorithm: startsWith;
    import std.array: replace;
    return type.startsWith("struct ")
        ? type.replace("struct ", "")
        : type;
}
