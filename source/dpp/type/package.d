/**
   Type translations
 */
module dpp.type;

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
            Complex: &translateComplex,
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

    // if it's anonymous, find the nickname, otherwise return the spelling
    string spelling() {
        import std.algorithm: canFind;
        // clang names anonymous types with a long name indicating where the type
        // was declared
        return type.spelling.canFind("(anonymous") ? context.popLastNickName : type.spelling;
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
    if(type.pointee is null) throw new Exception("null pointee for " ~ type.toString);
    assert(type.pointee !is null, "Pointee is null for " ~ type.toString);

    const isFunction =
        type.pointee.kind == Type.Kind.Unexposed &&
        (type.pointee.canonical.kind == Type.Kind.FunctionProto ||
         type.pointee.canonical.kind == Type.Kind.FunctionNoProto);

    // usually "*" but sometimes not needed if already a reference type
    const maybeStar = isFunction ? "" : "*";
    context.log("Pointee:           ", *type.pointee);
    context.log("Pointee canonical: ", type.pointee.canonical);

    const translateCanonical = type.pointee.kind == Type.Kind.Unexposed;
    context.log("Translate canonical? ", translateCanonical);

    const indentation = context.indentation;
    const rawType = translateCanonical
        ? translate(type.pointee.canonical, context.indent)
        : translate(*type.pointee, context.indent);
    context.setIndentation(indentation);

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
    return "ref " ~ translate(*type.canonical.pointee, context, translatingFunction);
}

private string translateComplex(in from!"clang".Type type,
                                ref from!"dpp.runtime.context".Context context,
                                in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe pure
{
    return "c" ~ translate(type.elementType, context, translatingFunction);
}

private string addModifiers(in from!"clang".Type type, in string translation) @safe pure {
    import std.array: replace;
    const realTranslation = translation.replace("const ", "");
    return type.isConstQualified
        ? `const(` ~  realTranslation ~ `)`
        : realTranslation;
}
