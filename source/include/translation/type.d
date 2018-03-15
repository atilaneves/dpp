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

        case Long:
            version(Windows)
                return "int";
            else
                return "long";

        case ULong:
            version(Windows)
                return "uint";
            else
                return "ulong";

        case Void: return "void";
        case NullPtr: return "void*";
        case Bool: return "bool";
        case WChar: return "wchar";
        case SChar: return "byte";
        case Char16: return "wchar";
        case Char32: return "dchar";
        case UChar: return "ubyte";
        case UShort: return "ushort";
        case Short: return "short";
        case Int: return "int";
        case UInt: return "uint";
        case LongLong: return "long";
        case ULongLong: return "ulong";
        case Float: return "float";
        case Double: return "double";
        case Elaborated: return type.spelling.cleanType;
        case ConstantArray: return type.spelling.cleanType;
    }
}

string cleanType(in string type) @safe pure {
    import std.array: replace;
    return type.replace("struct ", "");
}
