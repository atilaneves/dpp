/**
   Type translations
 */
module include.translation.type;

import include.from: from;

string translate(in from!"clang".Type type,
                 ref from!"include.runtime.context".Context context,
                 in from!"std.typecons".Flag!"translatingFunction" translatingFunction = from!"std.typecons".No.translatingFunction)
    @safe
{
    import include.translation.aggregate: spellingOrNickname;
    import clang: Type;
    import std.conv: text;
    import std.exception: enforce;
    import std.algorithm: countUntil, canFind, startsWith;
    import std.array: replace;

    switch(type.kind) with(Type.Kind) {

        default:
            throw new Exception(text("Type kind ", type.kind, " not supported: ", type));
            assert(0);

        case Long: return addModifiers(type, "c_long");
        case ULong: return addModifiers(type, "c_ulong");
        case Pointer: return translatePointer(type, context.indent).cleanType;
        case Typedef:
            // Here we may get a Typedef with a canonical type of Enum. It might be worth
            // translating to int for function parameters
            return addModifiers(type, type.spelling.cleanType);
        case Void: return addModifiers(type, "void");
        case NullPtr: return addModifiers(type, "void*");
        case Bool: return addModifiers(type, "bool");
        case WChar: return addModifiers(type, "wchar");
        case SChar: return addModifiers(type, "byte");
        case Char16: return addModifiers(type, "wchar");
        case Char32: return addModifiers(type, "dchar");
        case UChar: return addModifiers(type, "ubyte");
        case UShort: return addModifiers(type, "ushort");
        case Short: return addModifiers(type, "short");
        case Int: return addModifiers(type, "int");
        case UInt: return addModifiers(type, "uint");
        case LongLong: return addModifiers(type, "long");
        case ULongLong: return addModifiers(type, "ulong");
        case Float: return addModifiers(type, "float");
        case Double: return addModifiers(type, "double");
        case Char_U: return addModifiers(type, "ubyte");
        case Char_S: return addModifiers(type, "char");
        case Int128: return addModifiers(type, "cent");
        case UInt128: return addModifiers(type, "ucent");
        case Float128: return addModifiers(type, "real");
        case Half: return addModifiers(type, "float");
        case LongDouble: return addModifiers(type, "real");
        case Enum: return addModifiers(type, type.spelling.cleanType);
        case FunctionProto: return translateFunctionProto(type, context);
        case Record:

            // see it.compile.projects.va_list
            if(type.spelling == "struct __va_list_tag")
                return "va_list";

            return addModifiers(type, type.spelling.replace("const ", ""));

        case FunctionNoProto:
            // FIXME - No idea what this means
            assert(type.spelling == "int ()");
            return "int";

        case Elaborated:
            // Here we may get an elaborated enum. It's possible to know that
            // because the spelling begins with "enum ". It might be worth
            // translating to int for function parameters
            const name = spellingOrNickname(type.spelling, context);
            return addModifiers(type, name).cleanType;

        case ConstantArray:
            context.indent.log("Constant array of # ", type.numElements);
            return translatingFunction
                ? translate(type.elementType, context) ~ `*`
                : translate(type.elementType, context) ~ `[` ~ type.numElements.text ~ `]`;

        case IncompleteArray:
            const dType = translate(type.elementType, context);
            // if translating a function, we want C's T[] to translate
            // to T*, otherwise we want a flexible array
            return translatingFunction ? dType ~ `*` : dType ~ "[0]";
    }
}

private string addModifiers(in from!"clang".Type type, in string translation) @safe pure {
    import std.array: replace;
    const realTranslation = translation.replace("const ", "");
    return type.isConstQualified
        ? `const(` ~  realTranslation ~ `)`
        : realTranslation;
}

private string translatePointer(in from!"clang".Type type,
                                ref from!"include.runtime.context".Context context)
    @safe
{
    import clang: Type;
    import std.conv: text;

    assert(type.kind == Type.Kind.Pointer, "type kind not Pointer");
    if(type.pointee is null) throw new Exception("null pointee for " ~ type.toString);
    assert(type.pointee !is null, "Pointee is null for " ~ type.toString);

    const isFunctionProto = type.pointee.kind == Type.Kind.Unexposed &&
        type.pointee.canonical.kind == Type.Kind.FunctionProto;

    // usually "*" but sometimes not needed if already a reference type
    const pointer = isFunctionProto ? "" : "*";
    context.log("Pointee:           ", *type.pointee);
    context.log("Pointee canonical: ", type.pointee.canonical);

    const translateCanonical = type.pointee.kind == Type.Kind.Unexposed;
    context.log("Translate canonical? ", translateCanonical);

    const rawType = translateCanonical
        ? translate(type.pointee.canonical, context)
        : translate(*type.pointee, context);

    context.log("Raw type: ", rawType);

    // Only add top-level const if it's const all the way down
    bool addConst() @trusted {
        auto ptr = &type;
        while(ptr.kind == Type.Kind.Pointer) {
            if(!ptr.isConstQualified || !ptr.pointee.isConstQualified)
                return false;
            ptr = ptr.pointee;
        }

        return true;
    }

    const ptrType = addConst
        ? `const(` ~ rawType ~ pointer ~ `)`
        : rawType ~ pointer;

    return ptrType;
}

// currently only getting here from function pointer variables
// with have kind unexposed but canonical kind FunctionProto
private string translateFunctionProto(in from!"clang".Type type,
                                      ref from!"include.runtime.context".Context context)
    @safe
{
    import std.conv: text;
    import std.algorithm: map;
    import std.array: join, array;

    const params = type.paramTypes.map!(a => translate(a, context)).array;
    const variadicParams = type.isVariadicFunction ? ["..."] : [];
    const allParams = params ~ variadicParams;
    return text(translate(type.returnType, context), " function(", allParams.join(", "), ")");
}

string cleanType(in string type) @safe pure {
    import std.array: replace;
    return type.replace("struct ", "struct_").replace("union ", "union_").replace("enum ", "enum_");
}
