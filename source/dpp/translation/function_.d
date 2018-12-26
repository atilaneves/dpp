/**
   Function translations.
 */
module dpp.translation.function_;

import dpp.from;


enum OPERATOR_PREFIX = "operator";


string[] translateFunction(in from!"clang".Cursor cursor,
                           ref from!"dpp.runtime.context".Context context)
    @safe
    in(
        cursor.kind == from!"clang".Cursor.Kind.FunctionDecl ||
        cursor.kind == from!"clang".Cursor.Kind.CXXMethod ||
        cursor.kind == from!"clang".Cursor.Kind.Constructor ||
        cursor.kind == from!"clang".Cursor.Kind.Destructor ||
        cursor.kind == from!"clang".Cursor.Kind.ConversionFunction ||
        cursor.kind == from!"clang".Cursor.Kind.FunctionTemplate
    )
    do
{
    import dpp.translation.dlang: maybeRename, maybePragma;
    import dpp.translation.aggregate: maybeRememberStructs;
    import dpp.translation.type: translate;
    import clang: Cursor, Type;
    import std.array: join, array;
    import std.conv: text;
    import std.algorithm: any, endsWith, canFind;
    import std.typecons: Yes;

    if(ignoreFunction(cursor)) return [];

    // FIXME - stop special casing the move ctor
    auto moveCtorLines = maybeMoveCtor(cursor, context);
    if(moveCtorLines) return moveCtorLines;

    string[] lines;

    lines ~= maybeCopyCtor(cursor, context);
    lines ~= maybeOperator(cursor, context);

    maybeRememberStructs(paramTypes(cursor), context);

    const spelling = functionSpelling(cursor, context);

    lines ~= [
        maybePragma(cursor, context) ~ functionDecl(cursor, context, spelling)
    ];

    context.log("");

    return lines;
}

private bool ignoreFunction(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor, Type, Token;
    import std.algorithm: canFind;

    // C++ partial specialisation function bodies
    if(cursor.semanticParent.kind == Cursor.Kind.ClassTemplatePartialSpecialization &&
       cursor.semanticParent.type.kind == Type.Kind.Unexposed)
        return true;

    // FIXME
    if(cursor.semanticParent.kind == Cursor.Kind.ClassTemplate &&
       cursor.semanticParent.spelling == "vector")
        return true;


    // C++ deleted functions
    if(cursor.tokens.canFind(Token(Token.Kind.Keyword, "delete"))) return true;

    // FIXME - no default contructors for structs in D
    // We're not even checking if it's a struct here, so classes are being
    // affected for no reason.
    if(cursor.kind == Cursor.Kind.Constructor && numParams(cursor) == 0) return true;

    return false;
}

private string functionDecl(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    in string spelling,
    in from!"std.typecons".Flag!"names" names = from!"std.typecons".No.names
)
    @safe
{
    import dpp.translation.template_: translateTemplateParams;
    import std.conv: text;
    import std.algorithm: endsWith;
    import std.array: join;

    context.log("Function return type (raw):        ", cursor.type.returnType);
    const returnType = returnType(cursor, context);
    context.log("Function return type (translated): ", returnType);

    const params = translateAllParamTypes(cursor, context, names).join(", ");
    context.log("Translated parameters: '", params, "'");
    // const C++ method?
    const const_ = cursor.isConstCppMethod ? " const" : "";

    auto templateParams = translateTemplateParams(cursor, context);
    const ctParams = templateParams.empty
        ? ""
        : "(" ~ templateParams.join(", ") ~ ")"
        ;

    return text(returnType, " ", spelling, ctParams, "(", params, ") @nogc nothrow", const_, ";");
}

private string returnType(in from!"clang".Cursor cursor,
                          ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.type: translate;
    import clang: Cursor;
    import std.typecons: Yes;

    const indentation = context.indentation;

    const dType = cursor.kind == Cursor.Kind.Constructor || cursor.kind == Cursor.Kind.Destructor
        ? ""
        : translate(cursor.returnType, context, Yes.translatingFunction);

    context.setIndentation(indentation);

    const maybeStatic = cursor.storageClass == Cursor.StorageClass.Static ? "static " : "";

    return maybeStatic ~ dType;
}

private string[] maybeOperator(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{
    import std.algorithm: map;
    import std.array: join, array;
    import std.typecons: Yes;
    import std.range: iota;
    import std.conv: text;

    if(!isSupportedOperatorInD(cursor)) return [];

    const params = translateAllParamTypes(cursor, context).array;

    return [
        // remove semicolon from the end with [0..$-1]
        `extern(D) ` ~ functionDecl(cursor, context, operatorSpellingD(cursor, context), Yes.names)[0..$-1],
        `{`,
        `    return ` ~ operatorSpellingCpp(cursor, context) ~ `(` ~ params.length.iota.map!(a => text("arg", a)).join(", ") ~ `);`,
        `}`,
    ];
}

private bool isSupportedOperatorInD(in from!"clang".Cursor cursor) @safe nothrow {
    import clang: Cursor;
    import std.algorithm: map, canFind;

    if(!isOperator(cursor)) return false;
    // No D support for free function operator overloads
    if(cursor.semanticParent.kind == Cursor.Kind.TranslationUnit) return false;

    const cppOperator = cursor.spelling[OPERATOR_PREFIX.length .. $];
    const unsupportedSpellings = [`!`, `,`, `&&`, `||`, `->`, `->*`];
    if(unsupportedSpellings.canFind(cppOperator)) return false;

    if(isUnaryOperator(cursor) && cppOperator == "&") return false;
    if(!isUnaryOperator(cursor) && !isBinaryOperator(cursor)) return false;

     return true;
}

private bool isOperator(in from!"clang".Cursor cursor) @safe pure nothrow {
    import std.algorithm: startsWith;
    return
        cursor.spelling.startsWith(OPERATOR_PREFIX)
        && cursor.spelling.length > OPERATOR_PREFIX.length
        && cursor.spelling[OPERATOR_PREFIX.length] != '_'
        ;
}


private string functionSpelling(in from!"clang".Cursor cursor,
                                ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.algorithm: startsWith;

    if(cursor.kind == Cursor.Kind.Constructor) return "this";
    if(cursor.kind == Cursor.Kind.Destructor) return "~this";

    if(isOperator(cursor)) return operatorSpellingCpp(cursor, context);

    // if no special case
    return context.rememberLinkable(cursor);
}

private string operatorSpellingD(in from!"clang".Cursor cursor,
                                 ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.range: walkLength;
    import std.algorithm: canFind;
    import std.conv: text;

    const cppOperator = cursor.spelling[OPERATOR_PREFIX.length .. $];

    if(cursor.kind == Cursor.Kind.ConversionFunction) {
        return `opCast(T: ` ~ returnType(cursor, context) ~ `)`;
    }

    if(cppOperator.length > 1 &&
       cppOperator[$-1] == '=' &&
       (cppOperator.length != 2 || !['=', '!', '<', '>'].canFind(cppOperator[0])))
        return `opOpAssign(string op: "` ~ cppOperator[0 .. $-1] ~ `")`;

    assert(isUnaryOperator(cursor) || isBinaryOperator(cursor),
           text("Cursor is neither a unary or binary operator: ", cursor, "@", cursor.sourceRange.start));
    const dFunction = isBinaryOperator(cursor) ? "opBinary" : "opUnary";

    // Some of the operators here have empty parentheses around them. This is to
    // to make them templates and only be instantiated if needed. See #102.
    switch(cppOperator) {
        default: return dFunction ~ `(string op: "` ~ cppOperator ~ `")`;
        case "=": return `opAssign()`;
        case "()": return `opCall()`;
        case "[]": return `opIndex()`;
        case "==": return `opEquals()`;
    }
}

private bool isUnaryOperator(in from!"clang".Cursor cursor) @safe nothrow {
    return isOperator(cursor) && numParams(cursor) == 0;
}

private bool isBinaryOperator(in from!"clang".Cursor cursor) @safe nothrow {
    return isOperator(cursor) && numParams(cursor) == 1;
}

private long numParams(in from!"clang".Cursor cursor) @safe nothrow {
    import std.range: walkLength;
    return paramTypes(cursor).walkLength;
}

private string operatorSpellingCpp(in from!"clang".Cursor cursor,
                                   ref from!"dpp.runtime.context".Context context)
    @safe
    in(isOperator(cursor))
do
{
    import dpp.translation.type: translate;
    import dpp.translation.exception: UntranslatableException;
    import clang: Cursor;
    import std.string: replace;
    import std.algorithm: startsWith;

    const operator = cursor.spelling[OPERATOR_PREFIX.length .. $];

    if(cursor.kind == Cursor.Kind.ConversionFunction) {
        return "opCppCast_" ~ translate(cursor.returnType, context).replace(".", "_");
    }

    switch(operator) {
        default:
            if(operator.startsWith(`""`))  // user-defined string literal
                throw new UntranslatableException("Cannot translate user-defined literals");

            throw new Exception("Unknown C++ spelling for operator '" ~ operator ~ "'");

        case        "+":  return `opCppPlus`;
        case        "-":  return `opCppMinus`;
        case       "++":  return `opCppIncrement`;
        case       "--":  return `opCppDecrement`;
        case        "*":  return `opCppMul`;
        case        "/":  return `opCppDiv`;
        case        "&":  return `opCppAmpersand`;
        case        "~":  return `opCppTilde`;
        case        "%":  return `opCppMod`;
        case        "^":  return `opCppCaret`;
        case        "|":  return `opCppPipe`;
        case        "=":  return `opCppAssign`;
        case       ">>":  return `opCppRShift`;
        case       "<<":  return `opCppLShift`;
        case       "->":  return `opCppArrow`;
        case        "!":  return `opCppBang`;
        case       "&&":  return `opCppAnd`;
        case       "||":  return `opCppOr`;
        case        ",":  return `opCppComma`;
        case      "->*":  return `opCppArrowStar`;
        case       "+=":  return `opCppPlusAssign`;
        case       "-=":  return `opCppMinusAssign`;
        case       "*=":  return `opCppMulAssign`;
        case       "/=":  return `opCppDivAssign`;
        case       "%=":  return `opCppModAssign`;
        case       "^=":  return `opCppCaretAssign`;
        case       "&=":  return `opCppAmpersandAssign`;
        case       "|=":  return `opCppPipeAssign`;
        case      ">>=":  return `opCppRShiftAssign`;
        case      "<<=":  return `opCppLShiftAssign`;
        case       "()":  return `opCppCall`;
        case       "[]":  return `opCppIndex`;
        case       "==":  return `opCppEquals`;
        case       "!=":  return `opCppNotEquals`;
        case       "<=":  return `opCppLessEquals`;
        case       ">=":  return `opCppMoreEquals`;
        case        "<":  return `opCppLess`;
        case        ">":  return `opCppMore`;
        case      " new": return `opCppNew`;
        case    " new[]": return `opCppNewArray`;
        case   " delete": return `opCppDelete`;
        case " delete[]": return `opCppDeleteArray`;
    }

    assert(0);
}


// Add a non-const ref that forwards to the const ref copy ctor
// so that lvalues don't match the by-value ctor
private string[] maybeCopyCtor(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{

    import dpp.translation.dlang: maybeRename, maybePragma;
    import dpp.translation.type: translate;
    import clang: Cursor, Type;

    if(!cursor.isCopyConstructor) return [];

    const param = params(cursor).front;
    const translated = translateFunctionParam(cursor, param, context);
    const dType = translated["ref const(".length .. $ - 1];  // remove the constness

    return [
        `this(ref ` ~ dType ~ ` other)`,
        `{`,
        `   this(*cast(const ` ~ dType ~ `*) &other);`,
        `}`,
    ];
}


private string[] maybeMoveCtor(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{

    import dpp.translation.dlang: maybeRename, maybePragma;
    import dpp.translation.type: translate;
    import clang: Cursor, Type;

    if(!cursor.isMoveConstructor) return [];

    const paramType = () @trusted {  return paramTypes(cursor).front; }();
    const pointee = translate(paramType.pointee, context);

    return [
        maybePragma(cursor, context) ~ " this(" ~ pointee ~ "*);",
        "this(" ~ translate(paramType, context) ~ " wrapper) {",
        "    this(wrapper.ptr);",
        "    *wrapper.ptr = typeof(*wrapper.ptr).init;",
        "}",
        "this(" ~ pointee ~ " other)",
        "{",
        "    this(&other);",
        "}",
    ];
}

// includes C variadic params
private auto translateAllParamTypes(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    in from!"std.typecons".Flag!"names" names = from!"std.typecons".No.names,
)
    @safe
{
    import clang: Cursor;
    import std.algorithm: endsWith, map;
    import std.range: enumerate, chain;
    import std.conv: text;

    // Here we used to check that if there were no parameters and the language is C,
    // then the correct translation in D would be (...);
    // However, that's not allowed in D. It just so happens that C production code
    // exists that doesn't bother with (void), so instead of producing something that
    // doesn't compile, we compromise and assume the user meant (void)

    auto paramTypes = translateParamTypes(cursor, context);
    const isVariadic =
        cursor.type.spelling.endsWith("...)")
        && cursor.kind != Cursor.Kind.FunctionTemplate
        ;
    const variadicParams = isVariadic ? ["..."] : [];

    return enumerate(chain(paramTypes, variadicParams))
        .map!(a => names ? a[1] ~ text(" arg", a[0]) : a[1])
        ;
}

// does not include C variadic params
auto translateParamTypes(in from!"clang".Cursor cursor,
                         ref from!"dpp.runtime.context".Context context)
    @safe
{
    import std.algorithm: map;
    import std.range: tee, enumerate;

    return params(cursor)
        .enumerate
        .tee!((a) { context.log("    Function param #", a[0], " type: ", a[1].type, "  canonical ", a[1].type.canonical); })
        .map!(t => translateFunctionParam(cursor, t[1], context))
        ;
}


// translate a ParmDecl
private string translateFunctionParam(in from!"clang".Cursor function_,
                                      in from!"clang".Cursor param,
                                      ref from!"dpp.runtime.context".Context context)
    @safe
{

    import dpp.translation.type: translate;
    import clang: Type, Language;
    import std.typecons: Yes;
    import std.array: replace;

    // See #43
    const(Type) deunexpose(in Type type) {
        return type.kind == Type.Kind.Unexposed && function_.language != Language.CPlusPlus
            ? type.canonical
            : type;
    }

    // See contract.ctor.copy.definition.declartion for libclang silliness leading to this.
    // If the enclosing struct/class is templated and the function isn't, then we might
    // get "type-parameter-0-0" spellings even when the actual name is e.g. `T`.
    const numAggTemplateParams = function_.semanticParent.templateParams.length;
    const numFunTemplateParams = function_.templateParams.length;

    // HACK
    // FIXME: not sure what to do if the numbers aren't exactly 1 and 0
    const useAggTemplateParamSpelling = numAggTemplateParams == 1 && numFunTemplateParams == 0;
    const aggTemplateParamSpelling = useAggTemplateParamSpelling
        ? function_.semanticParent.templateParams[0].spelling
        : "";
    const translation = translate(deunexpose(param.type), context, Yes.translatingFunction);

    return useAggTemplateParamSpelling
        ? translation.replace("type_parameter_0_0", aggTemplateParamSpelling)
        : translation;
}

private auto paramTypes(in from!"clang".Cursor cursor) @safe {
    import std.algorithm: map;
    return params(cursor).map!(a => a.type) ;
}

private auto params(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor;
    import std.algorithm: filter;

    return cursor
        .children
        .filter!(a => a.kind == Cursor.Kind.ParmDecl)
        ;
}
