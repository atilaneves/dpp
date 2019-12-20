/**
   Type translations
 */
module dpp.translation.type;


import dpp.from: from;


alias Translator = string function(
    in from!"clang".Type type,
    ref from!"dpp.runtime.context".Context context,
    in from!"std.typecons".Flag!"translatingFunction" translatingFunction
) @safe;

alias Translators = Translator[from!"clang".Type.Kind];


string translate(in from!"clang".Type type,
                 ref from!"dpp.runtime.context".Context context,
                 in from!"std.typecons".Flag!"translatingFunction" translatingFunction = from!"std.typecons".No.translatingFunction)
    @safe
{
    import dpp.translation.exception: UntranslatableException;
    import std.conv: text;
    import std.array: replace;

    if(type.kind !in translators)
        throw new UntranslatableException(text("Type kind ", type.kind, " not supported: ", type));

    const translation = translators[type.kind](type, context, translatingFunction);

    // hack for std::function since function is a D keyword
    return translation.replace(`function!`, `function_!`);
}


private Translators translators() @safe {
    static Translators ret;
    if(ret == ret.init) ret = translatorsImpl;
    return ret;
}


private Translators translatorsImpl() @safe pure {
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
@safe
{
    return "";
}


private string simple(string translation)
                     (in from!"clang".Type type,
                      ref from!"dpp.runtime.context".Context context,
                      in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe
{
    return addModifiers(type, translation);
}


private string translateRecord(in from!"clang".Type type,
                               ref from!"dpp.runtime.context".Context context,
                               in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe
{

    // see it.compile.projects.va_list
    return type.spelling == "struct __va_list_tag"
        ? "va_list"
        : translateAggregate(type, context, translatingFunction);
}

private string translateAggregate(in from!"clang".Type type,
                                  ref from!"dpp.runtime.context".Context context,
                                  in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe
{
    import dpp.clang: namespace, typeNameNoNs;
    import std.array: replace, join;
    import std.algorithm: canFind, countUntil, map;
    import std.range: iota;
    import std.typecons: No;

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

            const ns = type.declaration.namespace;
            // no namespace, no problem
            if(ns.isInvalid) {
                import std.array : split;

                string[] elems = type.spelling.split(" ");
                string typeName = elems[$ - 1];
                string spelling = context.spelling(typeName);
                context.rememberSpelling(typeName, spelling);
                elems[$ - 1] = spelling;
                return elems.join(" ");
            }

            // look for the namespace name in the declaration
            const startOfNsIndex = type.spelling.countUntil(ns.spelling);

            // The namespace spelling is always what's considered the namespace in the FQN.
            // The spelling we get from the cursor itself might not contain this namespace
            // spelling if there's an alias.
            // See it.cpp.opaque.paramater.exception_ptr
            const hiddenNS = !type.spelling.canFind(ns.spelling);

            if(startOfNsIndex != -1) {
                // +2 due to `::`
                const endOfNsIndex = startOfNsIndex + ns.spelling.length + 2;
                // "subtract" the namespace away
                return type.spelling[endOfNsIndex .. $];
            } else if(hiddenNS) {
                // this block deals with cases where there's a name alias
                // and the NS doesn't show up how it's spelt but does show up
                // in the FQN.
                // See it.cpp.opaque.paramater.exception_ptr
                const noNs = type.declaration.typeNameNoNs;
                const endOfNsIndex = type.spelling.countUntil(noNs);

                if(endOfNsIndex == -1)
                    throw new Exception("Could not find namespaceless '" ~ noNs ~ "' in type '" ~ type.spelling ~ "'");
                return type.spelling[endOfNsIndex .. $];
            } else {
                return type.spelling;
            }
        }()
         // FIXME - why doesn't `translateString` work here?
         .replace("::", ".")
         .replace("typename ", "")
         ;

        // Clang template types have a spelling such as `Foo<unsigned int, unsigned short>`.
        // We need to extract the "base" name (e.g. Foo above) then translate each type
        // template argument (e.g. `unsigned long` is not a D type)
        if(type.numTemplateArguments > 0) {
            const openAngleBracketIndex = tentative.countUntil("<");
            // this might happen because of alises, e.g. std::string is really std::basic_stream<char>
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
                            // Never translating function if translating a type template argument
                            return translate(type.typeTemplateArgument(i), context, No.translatingFunction);
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
        .translateElaborated(context)
        .replace("<", "!(")
        .replace(">", ")")
        ;
}


private string translateConstantArray(in from!"clang".Type type,
                                      ref from!"dpp.runtime.context".Context context,
                                      in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe
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
@safe
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
@safe
{
    const dType = translate(type.elementType, context);
    // if translating a function, we want C's T[] to translate
    // to T*, otherwise we want a flexible array
    return translatingFunction ? dType ~ `*` : dType ~ "[0]";

}

private string translateTypedef(in from!"clang".Type type,
                                ref from!"dpp.runtime.context".Context context,
                                in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
@safe
{
    const translation = translate(type.declaration.underlyingType, context, translatingFunction);
    return addModifiers(type, translation);
}

private string translatePointer(in from!"clang".Type type,
                                ref from!"dpp.runtime.context".Context context,
                                in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe
    in(type.kind == from!"clang".Type.Kind.Pointer || type.kind == from!"clang".Type.Kind.MemberPointer)
    in(!type.pointee.isInvalid)
    do
{
    import clang: Type;
    import std.conv: text;
    import std.typecons: Yes;

    const isFunction =
        type.pointee.canonical.kind == Type.Kind.FunctionProto ||
        type.pointee.canonical.kind == Type.Kind.FunctionNoProto;

    // `function` in D is already a pointer, so no need to add a `*`.
    // Otherwise, add `*`.
    const maybeStar = isFunction ? "" : "*";
    context.log("Pointee:           ", type.pointee);
    context.log("Pointee canonical: ", type.pointee.canonical);

    // FIXME:
    // If the kind is unexposed, we want to get the canonical type.
    // Unless it's a type parameter, but that part I don't remember why anymore.
    const translateCanonical =
        type.pointee.kind == Type.Kind.Unexposed &&
        !isTypeParameter(type.pointee.canonical)
        ;
    context.log("Translate canonical? ", translateCanonical);
    const pointee = translateCanonical ? type.pointee.canonical : type.pointee;

    const indentation = context.indentation;
    // We always pretend that we're translating a function because from here it's
    // always a pointer
    const rawType = translate(pointee, context.indent, Yes.translatingFunction);
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

    version(Windows) {
        // Microsoft extension for pointers that doesn't compile
        // elsewhere. It tells the pointer may point to an unaligned
        // structure, for platforms where that is an optimization. Just
        // ignoring so it works here.
        import std.string;
        auto typePart = replace(rawType, "__unaligned ", "");
    } else {
        auto typePart = rawType;
   }

    const ptrType = addConst
        ? `const(` ~ typePart ~ maybeStar ~ `)`
        : typePart ~ maybeStar;
    return ptrType;
}

// FunctionProto is the type of a C/C++ function.
// We usually get here translating function pointers, since this would be the
// pointee type, but it could also be a C++ type template parameter such as
// in the case of std::function.
private string translateFunctionProto(
    in from!"clang".Type type,
    ref from!"dpp.runtime.context".Context context,
    in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe
{
    import std.conv: text;
    import std.algorithm: map;
    import std.array: join, array;

    const params = type.paramTypes.map!(a => translate(a, context)).array;
    const isVariadic = params.length > 0 && type.isVariadicFunction;
    const variadicParams = isVariadic ? ["..."] : [];
    const allParams = params ~ variadicParams;
    const returnType = translate(type.returnType, context);

    // The D equivalent of a function pointer (e.g. `int function(double, short)`)
    const funcPtrTransl = text(returnType, ` function(`, allParams.join(", "), `)`);

    // The D equivalent of a function type. There is no dedicate syntax for this.
    // In C/C++ it would be e.g. `int(double, short)`.
    const funcTransl = `typeof(*(` ~ funcPtrTransl ~ `).init)`;

    // In functions, function prototypes as parameters decay to
    // pointers similarly to how arrays do, so just return the
    // function pointer type. Otherwise return the function type.
    return translatingFunction ? funcPtrTransl : funcTransl;
}


private string translateLvalueRef(in from!"clang".Type type,
                                  ref from!"dpp.runtime.context".Context context,
                                  in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe
{
    const pointeeTranslation = translate(type.pointee, context, translatingFunction);
    return translatingFunction
        ? "ref " ~ pointeeTranslation
        : pointeeTranslation ~ "*";
}


private string translateRvalueRef(in from!"clang".Type type,
                                  ref from!"dpp.runtime.context".Context context,
                                  in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe
{
    const dtype = translate(type.canonical.pointee, context, translatingFunction);
    return `dpp.Move!(` ~ dtype ~ `)`;
}


private string translateComplex(in from!"clang".Type type,
                                ref from!"dpp.runtime.context".Context context,
                                in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe
{
    return "c" ~ translate(type.elementType, context, translatingFunction);
}

private string translateUnexposed(in from!"clang".Type type,
                                  ref from!"dpp.runtime.context".Context context,
                                  in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe
{
    import clang: Type;
    import std.string: replace;
    import std.algorithm: canFind;

    const canonical = type.canonical;

    // Deal with kinds we know how to deal with here
    if(canonical.kind != Type.Kind.Unexposed)
        return translate(canonical, context, translatingFunction);

    // FIXME: there should be a better way
    const spelling = type.spelling.canFind(" &&...")
        ? "auto ref " ~ type.spelling.replace(" &&...", "")
        : type.spelling;

    const translation =  translateString(spelling, context)
        // We might get template arguments here (e.g. `type-parameter-0-0`)
        // FIXME: this is a hack to get around libclang
        .replace("type-parameter-0-", "type_parameter_0_")
        ;

    return addModifiers(type, translation);
}

/**
   Translate possibly problematic C++ spellings
 */
string translateString(scope const string spelling,
                       in from!"dpp.runtime.context".Context context)
    @safe nothrow
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

string removeDppDecorators(in string spelling) @safe {
    import std.string : replace;
    return spelling.replace("__dpp_aggregate__ ", "");
}

// "struct Foo" -> Foo, "union Foo" -> Foo, "enum Foo" -> Foo
string translateElaborated(const scope string spelling,
                           ref from!"dpp.runtime.context".Context context) @safe {
    import dpp.runtime.context: Language;
    import std.array: replace;
    import std.algorithm : find;
    import std.string : split;
    import std.range.primitives;

    void remember(in string recordType) @safe pure {
        // '(' and ')' because of the "const(...)" modifier
        string[] name = spelling.split!(a => a == '(' || a == ')' || a == ' ').find(recordType);
        while (!name.empty) {
            context.rememberAggregateTypeLine(name[1]);
            name = name[1..$-1].find(recordType);
        }
    }

    const rep = context.language == Language.C ? "__dpp_aggregate__ " : "";

    if (context.language == Language.C) {
        remember("struct");
        remember("union");
        remember("enum");
    }

    return spelling
        .replace("struct ", rep)
        .replace("union ", rep)
        .replace("enum ", rep)
    ;
}

private string translateSimdVector(in from!"clang".Type type,
                                   ref from!"dpp.runtime.context".Context context,
                                   in from!"std.typecons".Flag!"translatingFunction" translatingFunction)
    @safe
{
    import std.conv: text;
    import std.algorithm: canFind;
    import std.string: replace;

    const numBytes = type.numElements;
    const dtype =
        translate(type.elementType, context, translatingFunction).replace("c_", "") ~
        text(numBytes);

    const isUnsupportedType =
        [
            "long1", "char8", "short4", "ubyte8", "byte8", "ushort4", "short4",
            "uint2", "int2", "ulong1", "float2", "char16",
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
    @safe
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
    @safe
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
    @safe
{
    import std.conv: text;
    return text(`dpp.Opaque!(`, type.getSizeof, `)`);
}
