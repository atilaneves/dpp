/**
   Type translations
 */
module include.translation.type;

import include.from;

string translate(in from!"clang".Type type,
                 in from!"std.typecons".Flag!"translatingFunction" translatingFunction = from!"std.typecons".No.translatingFunction,
                 in from!"include.runtime.options".Options options =
                              from!"include.runtime.options".Options())
    @safe
{
    import include.translation.aggregate: spellingOrNickname;
    import clang: Type;
    import std.conv: text;
    import std.exception: enforce;
    import std.algorithm: countUntil, canFind;

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
        case Char_S: return "char";
        case Int128: return "cent";
        case UInt128: return "ucent";
        case Float128: return "real";
        case Half: return "float";
        case LongDouble: return "real";
        case Enum: return type.spelling;
        case FunctionProto: return translateFunctionProto(type);

        case Elaborated:
            return spellingOrNickname(type.spelling).cleanType;

        case ConstantArray:
            options.indent.log("Constant array of # ", type.numElements);
            return translate(type.elementType) ~ `[` ~ type.numElements.text ~ `]`;

        case IncompleteArray:
            const dType = translate(type.elementType);
            // if translating a function, we want C's T[] to translate
            // to T*, otherwise we want a flexible array
            return translatingFunction ? dType ~ `*` : dType ~ "[0]";
    }
}

string translatePointer(in from!"clang".Type type) @safe {
    import clang: Type;
    import std.conv: text;

    assert(type.kind == Type.Kind.Pointer, "type kind not Pointer");
    if(type.pointee is null) throw new Exception("null pointee for " ~ type.toString);
    assert(type.pointee !is null, "Pointee is null for " ~ type.toString);

    if(type.pointee.kind == Type.Kind.Unexposed &&
       type.pointee.canonical.kind == Type.Kind.FunctionProto)
        return translate(type.pointee.canonical);

    const rawType = translate(*type.pointee);
    const pointeeType =  type.pointee.isConstQualified
        ? `const(` ~ rawType ~ `)`
        : rawType;

    return pointeeType ~ `*`;
}

// currently only getting here from function pointer variables
// with have kind unexposed but canonical kind FunctionProto
private string translateFunctionProto(in from!"clang".Type type) @safe {
    import std.conv: text;
    import std.algorithm: map;
    import std.array: join, array;

    const params = type.paramTypes.map!(a => translate(a)).array;
    const variadicParams = type.isVariadicFunction ? ["..."] : [];
    const allParams = params ~ variadicParams;
    return text(translate(type.returnType), " function(", allParams.join(", "), ")");
}

string cleanType(in string type) @safe pure {
    import std.array: replace;
    return type.replace("struct ", "struct_").replace("union ", "union_").replace("enum ", "enum_");
}
