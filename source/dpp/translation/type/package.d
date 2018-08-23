/**
   Type translations
 */
module dpp.translation.type;


import dpp.from: from;


alias Translator = string function(
    in from!"clang".Type type,
    ref from!"dpp.runtime.context".Context context,
    in from!"std.typecons".Flag!"translatingFunction" translatingFunction
) @safe pure;

alias Translators = Translator[from!"clang".Type.Kind];


string translate(in from!"clang".Type type,
                 ref from!"dpp.runtime.context".Context context,
                 in from!"std.typecons".Flag!"translatingFunction" translatingFunction = from!"std.typecons".No.translatingFunction)
    @safe pure
{
    import std.conv: text;
    if(type.kind !in translators)
        throw new Exception(text("Type kind ", type.kind, " not supported: ", type));

    return translators[type.kind](type, context, translatingFunction);
}

Translators translators() @safe pure {
    import clang: Type;

    with(Type.Kind) {
        return [
            Long: &simple!"c_long",
            ULong: &simple!"c_ulong",
            Void: &simple!"void",
            NullPtr: &simple!"void*",
            Bool: &simple!"bool",
            WChar: &simple!"wchar",
            SChar: &simple!"byte",
            Char16: &simple!"wchar",
            Char32: &simple!"dchar",
            UChar: &simple!"ubyte",
            UShort: &simple!"ushort",
            Short: &simple!"short",
            Int: &simple!"int",
            UInt: &simple!"uint",
            LongLong: &simple!"long",
            ULongLong: &simple!"ulong",
            Float: &simple!"float",
            Double: &simple!"double",
            Char_U: &simple!"ubyte",
            Char_S: &simple!"char",
            Int128: &simple!"cent",
            UInt128: &simple!"ucent",
            Float128: &simple!"real",
            Half: &simple!"float",
            LongDouble: &simple!"real",
            Enum: &translateAggregate,
            Pointer: &translatePointer,
            FunctionProto: &translateFunctionProto,
            Record: &translateRecord,
            FunctionNoProto: &translateFunctionProto,
            Elaborated: &translateAggregate,
            ConstantArray: &translateConstantArray,
            IncompleteArray: &translateIncompleteArray,
            Typedef: &translateTypedef,
            LValueReference: &translateLvalueRef,
            RValueReference: &translateRvalueRef,
            Complex: &translateComplex,
            Unexposed: &translateUnexposed,
            DependentSizedArray: &translateDependentSizedArray,
            Vector: &translateSimdVector,
        ];
    }
}


private string simple(string translation)
                     (in from!"clang".Type type,
                      ref from!"dpp.runtime.context".Context context,
                      in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe pure
{
    return addModifiers(type, translation);
}


private string translateRecord(in from!"clang".Type type,
                               ref from!"dpp.runtime.context".Context context,
                               in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe pure
{
    // see it.compile.projects.va_list
    return type.spelling == "struct __va_list_tag"
        ? "va_list"
        : translateAggregate(type, context, translatingFunction);
}

private string translateAggregate(in from!"clang".Type type,
                                  ref from!"dpp.runtime.context".Context context,
                                  in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe pure
{
    import std.array: replace;
    import std.algorithm: canFind;

    // if it's anonymous, find the nickname, otherwise return the spelling
    string spelling() {
        // clang names anonymous types with a long name indicating where the type
        // was declared, so we check here with `hasAnonymousSpelling`
        if(hasAnonymousSpelling(type)) return context.spellingOrNickname(type.declaration);

        // A struct in a namespace will have a type of kind Record with the fully
        // qualified name (e.g. std::random_access_iterator_tag), but the cursor
        // itself has only the name (e.g. random_access_iterator_tag), so we get
        // the spelling from the type's declaration instead of from the type itself.
        // See it.cpp.templates.__copy_move and contract.namespace.struct.
        return type.spelling.canFind(":") ? type.declaration.spelling : type.spelling;
    }

    return addModifiers(type, spelling)
        // "struct Foo" -> Foo, "union Foo" -> Foo, "enum Foo" -> Foo
        .replace("struct ", "").replace("union ", "").replace("enum ", "")
        ;
}


private string translateConstantArray(in from!"clang".Type type,
                                      ref from!"dpp.runtime.context".Context context,
                                      in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe pure
{
    import std.conv: text;

    context.indent.log("Constant array of # ", type.numElements);

    return translatingFunction
        ? translate(type.elementType, context) ~ `*`
        : translate(type.elementType, context) ~ `[` ~ type.numElements.text ~ `]`;
}


private string translateDependentSizedArray(
    in from!"clang".Type type,
    ref from!"dpp.runtime.context".Context context,
    in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe pure
{
    import std.conv: text;
    import std.algorithm: find, countUntil;

    // FIXME: hacky, only works for the only test in it.cpp.class_.template (array)
    auto start = type.spelling.find("["); start = start[1 .. $];
    auto endIndex = start.countUntil("]");

    return translate(type.elementType, context) ~ `[` ~ start[0 .. endIndex] ~ `]`;
}


private string translateIncompleteArray(in from!"clang".Type type,
                                        ref from!"dpp.runtime.context".Context context,
                                        in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe pure
{
    const dType = translate(type.elementType, context);
    // if translating a function, we want C's T[] to translate
    // to T*, otherwise we want a flexible array
    return translatingFunction ? dType ~ `*` : dType ~ "[0]";

}

private string translateTypedef(in from!"clang".Type type,
                                ref from!"dpp.runtime.context".Context context,
                                in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe pure
{
    // Here we may get a Typedef with a canonical type of Enum. It might be worth
    // translating to int for function parameters
    return addModifiers(type, type.spelling);
}

private string translatePointer(in from!"clang".Type type,
                                ref from!"dpp.runtime.context".Context context,
                                in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe pure
{
    import clang: Type;
    import std.conv: text;

    assert(type.kind == Type.Kind.Pointer, "type kind not Pointer");
    assert(!type.pointee.isInvalid, "pointee is invalid");

    const isFunction =
        type.pointee.kind == Type.Kind.Unexposed &&
        (type.pointee.canonical.kind == Type.Kind.FunctionProto ||
         type.pointee.canonical.kind == Type.Kind.FunctionNoProto);

    // usually "*" but sometimes not needed if already a reference type
    const maybeStar = isFunction ? "" : "*";
    context.log("Pointee:           ", type.pointee);
    context.log("Pointee canonical: ", type.pointee.canonical);

    const translateCanonical = type.pointee.kind == Type.Kind.Unexposed;
    context.log("Translate canonical? ", translateCanonical);

    const indentation = context.indentation;
    const rawType = translateCanonical
        ? translate(type.pointee.canonical, context.indent)
        : translate(type.pointee, context.indent);
    context.setIndentation(indentation);

    context.log("Raw type: ", rawType);

    // Only add top-level const if it's const all the way down
    bool addConst() @trusted {
        auto ptr = Type(type);
        while(ptr.kind == Type.Kind.Pointer) {
            if(!ptr.isConstQualified || !ptr.pointee.isConstQualified)
                return false;
            ptr = ptr.pointee;
        }

        return true;
    }

    const ptrType = addConst
        ? `const(` ~ rawType ~ maybeStar ~ `)`
        : rawType ~ maybeStar;

    return ptrType;
}

// currently only getting here from function pointer variables
// with have kind unexposed but canonical kind FunctionProto
private string translateFunctionProto(in from!"clang".Type type,
                                      ref from!"dpp.runtime.context".Context context,
                                      in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe pure
{
    import std.conv: text;
    import std.algorithm: map;
    import std.array: join, array;

    const params = type.paramTypes.map!(a => translate(a, context)).array;
    const isVariadic = params.length > 0 && type.isVariadicFunction;
    const variadicParams = isVariadic ? ["..."] : [];
    const allParams = params ~ variadicParams;
    return text(translate(type.returnType, context), " function(", allParams.join(", "), ")");
}

private string translateLvalueRef(in from!"clang".Type type,
                                  ref from!"dpp.runtime.context".Context context,
                                  in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe pure
{
    return "ref " ~ translate(type.canonical.pointee, context, translatingFunction);
}

// we cheat and pretend it's a value
private string translateRvalueRef(in from!"clang".Type type,
                                  ref from!"dpp.runtime.context".Context context,
                                  in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe pure
{
    const dtype = translate(type.canonical.pointee, context, translatingFunction);
    return `dpp.Move!(` ~ dtype ~ `)`;
}


private string translateComplex(in from!"clang".Type type,
                                ref from!"dpp.runtime.context".Context context,
                                in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe pure
{
    return "c" ~ translate(type.elementType, context, translatingFunction);
}

private string translateUnexposed(in from!"clang".Type type,
                                  ref from!"dpp.runtime.context".Context context,
                                  in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe pure
{
    return type.spelling;
}

private string translateSimdVector(in from!"clang".Type type,
                                   ref from!"dpp.runtime.context".Context context,
                                   in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe pure
{
    import std.conv: text;
    import std.algorithm: canFind;

    const numBytes = type.numElements;
    const dtype =
        translate(type.elementType, context, translatingFunction) ~
        text(type.getSizeof / numBytes);

    const isUnsupportedType =
        [
            "long8", "short2", "char1", "double8", "ubyte1", "ushort2",
            "ulong8", "byte1",
        ].canFind(dtype);

    return isUnsupportedType ? "int /* FIXME: unsupported SIMD type */" : "core.simd." ~ dtype;
}


private string addModifiers(in from!"clang".Type type, in string translation) @safe pure {
    import std.array: replace;
    const realTranslation = translation.replace("const ", "").replace("volatile ", "");
    return type.isConstQualified
        ? `const(` ~  realTranslation ~ `)`
        : realTranslation;
}

bool hasAnonymousSpelling(in from!"clang".Type type) @safe pure nothrow {
    import std.algorithm: canFind;
    return type.spelling.canFind("(anonymous");
}
