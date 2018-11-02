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
            Int128: &simple!"Int128",
            UInt128: &simple!"UInt128",
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
            MemberPointer: &translatePointer, // FIXME #83
            Invalid: &ignore, // FIXME C++ stdlib <type_traits>
        ];
    }
}

private string ignore(in from!"clang".Type type,
                      ref from!"dpp.runtime.context".Context context,
                      in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe pure
{
    return "";
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
    import std.array: replace, join;
    import std.algorithm: canFind, countUntil, map;
    import std.range: iota;

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
        if(type.spelling.canFind(":")) return type.declaration.spelling;

        // Clang template types have a spelling such as `Foo<unsigned int, unsigned short>`.
        // We need to extract the "base" name (e.g. Foo above) then translate each type
        // template argument (`unsigned long` is not a D type)
        if(type.numTemplateArguments > 0) {
            const openAngleBracketIndex = type.spelling.countUntil("<");
            const baseName = type.spelling[0 .. openAngleBracketIndex];
            const templateArgsTranslation = type
                .numTemplateArguments
                .iota
                .map!((i) {
                    const kind = templateArgumentKind(type.typeTemplateArgument(i));
                    final switch(kind) with(TemplateArgumentKind) {
                        case GenericType:
                        case SpecialisedType:
                            return translate(type.typeTemplateArgument(i), context, translatingFunction);
                        case Value:
                            return templateParameterSpelling(type, i);
                    }
                 })
                .join(", ");
            return baseName ~ "!(" ~ templateArgsTranslation ~ ")";
        }

        return type.spelling;
    }

    return addModifiers(type, spelling)
        // "struct Foo" -> Foo, "union Foo" -> Foo, "enum Foo" -> Foo
        .replace("struct ", "")
        .replace("union ", "")
        .replace("enum ", "")
        .replace("<", "!(")
        .replace(">", ")")
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
    const translation = translate(type.declaration.underlyingType, context, translatingFunction);
    return addModifiers(type, translation);
}

private string translatePointer(in from!"clang".Type type,
                                ref from!"dpp.runtime.context".Context context,
                                in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe pure
{
    import clang: Type;
    import std.conv: text;

    assert(type.kind == Type.Kind.Pointer || type.kind == Type.Kind.MemberPointer, "type kind not Pointer");
    assert(!type.pointee.isInvalid, "pointee is invalid");

    const isFunction =
        type.pointee.canonical.kind == Type.Kind.FunctionProto ||
        type.pointee.canonical.kind == Type.Kind.FunctionNoProto;

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
    const typeToUse = type.canonical.isTypeParameter ? type : type.canonical;

    const pointeeTranslation = translate(typeToUse.pointee, context, translatingFunction);
    return translatingFunction
        ? "ref " ~ pointeeTranslation
        : pointeeTranslation ~ "*";
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
    import std.string: replace;

    const translation =  type.spelling
        .translateString
        // we might get template arguments here
        .replace("-", "_")
        ;

    return addModifiers(type, translation);
}

string translateString(in string spelling) @safe pure nothrow {
    import std.string: replace;
    return spelling
        .replace("<", "!(")
        .replace(">", ")")
        .replace("decltype", "typeof")
        .replace("typename ", "")
        .replace("template ", "")
        .replace("::", ".")
        .replace("volatile ", "")
        .replace("long long", "long")
        .replace("unsigned ", "u")
        .replace("&&", "")
        ;
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


bool isTypeParameter(in from!"clang".Type type) @safe pure nothrow {
    import std.algorithm: canFind;
    // See contract.typedef_.typedef to a template type parameter
    return type.spelling.canFind("type-parameter-");
}

/**
   libclang doesn't offer a lot of functionality when it comes to extracting
   template arguments from structs - this enum is the best we can do.
 */
enum TemplateArgumentKind {
    GenericType,
    SpecialisedType,
    Value,  // could be specialised or not
}

// type template arguments may be:
// Invalid - value (could be specialised or not)
// Unexposed - non-specialised type or
// anything else - specialised type
// The trick is figuring out if a value is specialised or not
TemplateArgumentKind templateArgumentKind(in from!"clang".Type type) @safe pure nothrow {
    import clang: Type;
    if(type.kind == Type.Kind.Invalid) return TemplateArgumentKind.Value;
    if(type.kind == Type.Kind.Unexposed) return TemplateArgumentKind.GenericType;
    return TemplateArgumentKind.SpecialisedType;
}

// e.g. template<> struct foo<false, true, int32_t>  ->  0: false, 1: true, 2: int
string translateTemplateParamSpecialisation(
    in from!"clang".Type templateType,
    in int index,
    ref from!"dpp.runtime.context".Context context) @safe pure
{
    return translateTemplateParamSpecialisation(templateType, templateType, index, context);
}


// e.g. template<> struct foo<false, true, int32_t>  ->  0: false, 1: true, 2: int
string translateTemplateParamSpecialisation(
    in from!"clang".Type cursorType,
    in from!"clang".Type type,
    in int index,
    ref from!"dpp.runtime.context".Context context) @safe pure
{
    import clang: Type;
    return type.kind == Type.Kind.Invalid
        ? templateParameterSpelling(cursorType, index)
        : translate(type, context);
}


// returns the indexth template parameter value from a specialised
// template struct/class cursor (full or partial)
// e.g. template<> struct Foo<int, 42, double> -> 1: 42
string templateParameterSpelling(in from!"clang".Type cursorType, int index) @safe pure {
    import std.algorithm: findSkip, until, OpenRight;
    import std.array: empty, save, split, array;
    import std.conv: text;

    auto spelling = cursorType.spelling.dup;
    if(!spelling.findSkip("<")) return "";

    auto templateParams = spelling.until(">", OpenRight.yes).array.split(", ");

    return templateParams[index].text;
}
