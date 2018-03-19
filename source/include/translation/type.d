/**
   Type translations
 */
module include.translation.type;

import include.from;

string translate(in from!"clang".Type type,
                 in from!"std.typecons".Flag!"translatingFunction" translatingFunction = from!"std.typecons".No.translatingFunction,
                 in from!"include.runtime.options".Options options =
                              from!"include.runtime.options".Options())
    @safe pure
{
    import clang: Type;
    import std.conv: text;
    import std.exception: enforce;
    import std.algorithm: countUntil;

    switch(type.kind) with(Type.Kind) {

        default:
            throw new Exception(text("Type kind ", type.kind, " not supported: ", type));
            assert(0);

        case Long: return "c_long";
        case ULong: return "c_ulong";
        case Pointer: return translatePointer(type).cleanType;
        case Typedef: return type.spelling.cleanType;
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
        case Char_U: return "ubyte";
        case Char_S: return "byte";
        case Int128: return "cent";
        case UInt128: return "ucent";
        case Float128: return "real";
        case Half: return "float";
        case LongDouble: return "real";
        case Elaborated: return type.spelling.cleanType;

        case ConstantArray:
            // -1 because clang inserts a space
            const bracketIndex = type.spelling.countUntil("[") - 1;
            enforce(bracketIndex > 0);
            return translateCType(type.spelling[0 .. bracketIndex]).cleanType ~ type.spelling[bracketIndex .. $];

        // this will look like "type []", so strip out the last 3 chars
        case IncompleteArray:
            const dType = translateCType(type.spelling[0 .. $-3]);
            return translatingFunction ? dType ~ `*` : dType ~ "[0]";
    }
}

string translatePointer(in from!"clang".Type type) @safe pure {
    import clang: Type;
    import std.algorithm: startsWith;
    import std.array: replace;

    assert(type.kind == Type.Kind.Pointer);

    return type.spelling.startsWith("const ")
        ? `const(` ~ translateCType(type.spelling.replace(" *", "").replace("const ", "")) ~ `)*`
        : type.spelling;
}

string translateFunctionPointerReturnType(in from!"clang".Type type) @safe pure {
    import clang: Type;
    import std.algorithm: countUntil;
    import std.exception: enforce;

    const functionPointerIndex = type.spelling.countUntil("(*)(");
    enforce(functionPointerIndex > 0, "Could not find function pointer in " ~ type.spelling);
    return translate(Type(Type.Kind.Pointer, type.spelling[0 .. functionPointerIndex]));
}

string translateFunctionProtoReturnType(in from!"clang".Type type) @safe pure {
    import clang: Type;
    import std.algorithm: countUntil;
    import std.exception: enforce;

    const parenIndex = type.spelling.countUntil("(");
    enforce(parenIndex > 0, "Could not find parameters in " ~ type.spelling);
    return translate(Type(Type.Kind.Pointer, type.spelling[0 .. parenIndex]));
}

string cleanType(in string type) @safe pure {
    import std.array: replace;
    return type.replace("struct ", "").replace("union ", "").replace("enum ", "");
}

/**
   Unfortunately, incomplete arrays have only their spelling to go on.
   It might be that other cursors are like this as well. So the type
   inside needs to be translated from a _string_ to the equivalent D type.
 */
string translateCType(in string type) @safe pure {
    import clang: Type;

    switch(type) with(Type.Kind) {

        // the type might be user-defined, so if we don't recognise it, return it
        default: return type.cleanType;

        case "char": return "char";
        case "const char": return "const(char)";
        case "signed char": return "byte";
        case "unsigned char": return translate(Type(UChar, type));
        case "short": return translate(Type(Short, type));
        case "const short": return `const(` ~ translate(Type(Short, type)) ~ `)`;
        case "unsigned short": return translate(Type(UShort, type));
        case "int": return translate(Type(Int, type));
        case "unsigned int": return translate(Type(UInt, type));
        case "long": return translate(Type(Long, type));
        case "unsigned long": return translate(Type(ULong, type));
        case "float": return translate(Type(Float, type));
        case "double": return translate(Type(Double, type));
        case "const char *const": return "const(char*)";
    }
}
