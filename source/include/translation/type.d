/**
   Type translations
 */
module include.translation.type;

import include.from;

string translate(in from!"clang".Type type) @safe pure {
    import clang: Type;
    import std.conv: text;
    import std.exception: enforce;

    switch(type.kind) with(Type.Kind) {

        default:
            enforce(false, text("Type kind ", type.kind, " not supported")); assert(0);

        case Int:
            return "int";

        case Long:
            version(Windows)
                return "int";
            else
                return "long";

        case Float:
            return "float";

        case Double:
            return "double";

        case Elaborated:
            return type.spelling.cleanType;

        case ConstantArray:
            return type.spelling.cleanType;
    }
}

string cleanType(in string type) @safe pure {
    import std.algorithm: startsWith;
    import std.array: replace;
    return type.startsWith("struct ")
        ? type.replace("struct ", "")
        : type;
}
