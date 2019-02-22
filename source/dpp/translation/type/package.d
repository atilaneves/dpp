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
    import dpp.translation.exception: UntranslatableException;
    import std.conv: text;

    if(type.kind !in translators)
        throw new UntranslatableException(text("Type kind ", type.kind, " not supported: ", type));

    return translators[type.kind](type, context, translatingFunction);
}


Translators translators() @safe pure {
    import clang: Type;

    with(Type.Kind) {
        return [
            Void: &simple!"void",
            NullPtr: &simple!"void*",

            Bool: &simple!"bool",

            WChar: &simple!"wchar",
            SChar: &simple!"byte",
            Char16: &simple!"wchar",
            Char32: &simple!"dchar",
            UChar: &simple!"ubyte",
            Char_U: &simple!"ubyte",
            Char_S: &simple!"char",

            UShort: &simple!"ushort",
            Short: &simple!"short",
            Int: &simple!"int",
            UInt: &simple!"uint",
            Long: &simple!"c_long",
            ULong: &simple!"c_ulong",
            LongLong: &simple!"long",
            ULongLong: &simple!"ulong",
            Int128: &simple!"Int128",
            UInt128: &simple!"UInt128",

            Float: &simple!"float",
            Double: &simple!"double",
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
            DependentSizedArray: &translateDependentSizedArray,
            Vector: &translateSimdVector,
            MemberPointer: &translatePointer, // FIXME #83
            Invalid: &ignore, // FIXME C++ stdlib <type_traits>
            Unexposed: &translateUnexposed,
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
    import dpp.clang: namespace;
    import std.array: replace, join;
    import std.algorithm: canFind, countUntil, map;
    import std.range: iota;

    // if it's anonymous, find the nickname, otherwise return the spelling
    string spelling() {
        // clang names anonymous types with a long name indicating where the type
        // was declared, so we check here with `hasAnonymousSpelling`
        if(hasAnonymousSpelling(type)) return context.spellingOrNickname(type.declaration);

        // If there's a namespace in the name, we have to remove it. To find out
        // what the namespace is called, we look at the type's declaration.
        // In libclang, the type has the FQN, but the cursor only has the name
        // without namespaces.
        const tentative = () {
            // no namespace, no problem
            if(!type.spelling.canFind(":")) return type.spelling;
            // look for the base name in the declaration
            const endOfNsIndex = type.spelling.countUntil(type.declaration.spelling);
            if(endOfNsIndex == -1)
                throw new Exception("Could not find '" ~ type.declaration.spelling ~ "' in '" ~ type.spelling ~ "'");
            // "subtract" the namespace away
            return type.spelling[endOfNsIndex .. $];
        }();

        // Clang template types have a spelling such as `Foo<unsigned int, unsigned short>`.
        // We need to extract the "base" name (e.g. Foo above) then translate each type
        // template argument (e.g. `unsigned long` is not a D type)
        if(type.numTemplateArguments > 0) {
            const openAngleBracketIndex = tentative.countUntil("<");
            // this might happen because of alises, e.g. std::string is really std::basic_stream<chas>
            if(openAngleBracketIndex == -1) return tentative;
            const baseName = tentative[0 .. openAngleBracketIndex];
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

        return tentative;
    }

    return addModifiers(type, spelling)
        .translateElaborated
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

    const translateCanonical =
        type.pointee.kind == Type.Kind.Unexposed && !isTypeParameter(type.pointee.canonical)
        ;
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
    const pointeeTranslation = translate(type.pointee, context, translatingFunction);
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
    import clang: Type;
    import std.string: replace;
    import std.algorithm: canFind;

    if(type.canonical.kind == Type.Kind.Record)
        return translateAggregate(type.canonical, context, translatingFunction);

    const spelling = type.spelling.canFind(" &&...")
        ? "auto ref " ~ type.spelling.replace(" &&...", "")
        : type.spelling;

    const translation =  translateString(spelling, context)
        // we might get template arguments here (e.g. `type-parameter-0-0`)
        .replace("type-parameter-0-", "type_parameter_0_")
        ;

    return addModifiers(type, translation);
}

/**
   Translate possibly problematic C++ spellings
 */
string translateString(in string spelling,
                       in from!"dpp.runtime.context".Context context)
    @safe pure nothrow
{
    import std.string: replace;
    import std.algorithm: canFind;

    string maybeTranslateTemplateBrackets(in string str) {
        return str.canFind("<") && str.canFind(">")
            ? str.replace("<", "!(").replace(">", ")")
            : str;
    }

    return
        maybeTranslateTemplateBrackets(spelling)
        .replace(context.namespace, "")
        .replace("decltype", "typeof")
        .replace("typename ", "")
        .replace("template ", "")
        .replace("::", ".")
        .replace("volatile ", "")
        .replace("long long", "long")
        .replace("long double", "double")
        .replace("unsigned ", "u")
        .replace("signed char", "char")  // FIXME?
        .replace("&&", "")
        .replace("...", "")  // variadics work differently in D
        ;
}


// "struct Foo" -> Foo, "union Foo" -> Foo, "enum Foo" -> Foo
string translateElaborated(in string spelling) @safe pure nothrow {
    import std.array: replace;
    return spelling
        .replace("struct ", "")
        .replace("union ", "")
        .replace("enum ", "")
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


// e.g. `template<> struct foo<false, true, int32_t>`  ->  0: false, 1: true, 2: int
string translateTemplateParamSpecialisation(
    in from!"clang".Type cursorType,
    in from!"clang".Type type,
    in int index,
    ref from!"dpp.runtime.context".Context context)
    @safe pure
{
    import clang: Type;
    return type.kind == Type.Kind.Invalid
        ? templateParameterSpelling(cursorType, index)
        : translate(type, context);
}


// returns the indexth template parameter value from a specialised
// template struct/class cursor (full or partial)
// e.g. template<> struct Foo<int, 42, double> -> 1: 42
string templateParameterSpelling(in from!"clang".Type cursorType,
                                 int index)
    @safe pure
{
    import dpp.translation.exception: UntranslatableException;
    import std.algorithm: findSkip, startsWith;
    import std.array: split;
    import std.conv: text;

    auto spelling = cursorType.spelling.dup;
    // If we pass this spelling has had everyting leading up to the opening
    // angle bracket removed.
    if(!spelling.findSkip("<")) return "";
    assert(spelling[$-1] == '>');

    const templateParams = spelling[0 .. $-1].split(", ");

    if(index < 0 || index >= templateParams.length)
        throw new UntranslatableException(
            text("index (", index, ") out of bounds for template params of length ",
                 templateParams.length, ":\n", templateParams));

    return templateParams[index].text;
}


string translateOpaque(in from!"clang".Type type)
    @safe pure
{
    import std.conv: text;
    return text(`dpp.Opaque!(`, type.getSizeof, `)`);
}
