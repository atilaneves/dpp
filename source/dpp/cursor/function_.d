/**
   Function translations.
 */
module dpp.cursor.function_;

import dpp.from;


enum OPERATOR_PREFIX = "operator";


string[] translateFunction(in from!"clang".Cursor cursor,
                           ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.cursor.dlang: maybeRename, maybePragma;
    import dpp.cursor.aggregate: maybeRememberStructs;
    import dpp.type: translate;
    import clang: Cursor, Type, Language;
    import std.array: join, array;
    import std.conv: text;
    import std.algorithm: any, endsWith;
    import std.typecons: Yes;

    assert(
        cursor.kind == Cursor.Kind.FunctionDecl ||
        cursor.kind == Cursor.Kind.CXXMethod ||
        cursor.kind == Cursor.Kind.Constructor ||
        cursor.kind == Cursor.Kind.Destructor ||
        cursor.kind == Cursor.Kind.ConversionFunction
    );

    // FIXME - stop special casing the move ctor
    auto moveCtorLines = maybeMoveCtor(cursor, context);
    if(moveCtorLines) return moveCtorLines;

    string[] lines;

    lines ~= maybeOperator(cursor, context);

    maybeRememberStructs(paramTypes(cursor), context);

    const spelling = functionSpelling(cursor, context);

    lines ~= [
        maybePragma(cursor, context) ~ functionDecl(cursor, context, spelling)
    ];

    return lines;
}

private string functionDecl(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    in string spelling,
    in from!"std.typecons".Flag!"names" names = from!"std.typecons".No.names
)
    @safe
{
    import std.conv: text;
    import std.algorithm: endsWith;
    import std.array: join;

    const returnType = returnType(cursor, context);
    const params = translateAllParamTypes(cursor, context, names);
    // const C++ method?
    const const_ = cursor.isConstCppMethod ? " const" : "";

    return text(returnType, " ", spelling, "(", params.join(", "), ") @nogc nothrow", const_, ";");
}

private string returnType(in from!"clang".Cursor cursor,
                          ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.type: translate;
    import clang: Cursor;
    import std.typecons: Yes;

    const indentation = context.indentation;
    context.log("Function return type (raw):        ", cursor.type.returnType);

    const dType = cursor.kind == Cursor.Kind.Constructor || cursor.kind == Cursor.Kind.Destructor
        ? ""
        : translate(cursor.returnType, context, Yes.translatingFunction);

    context.setIndentation(indentation);
    context.log("Function return type (translated): ", dType);

    const static_ = cursor.storageClass == Cursor.StorageClass.Static ? "static " : "";

    return static_ ~ dType;
}

private string[] maybeOperator(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{
    import std.algorithm: map;
    import std.array: join;
    import std.typecons: Yes;
    import std.range: iota;
    import std.conv: text;

    if(!isSupportedOperator(cursor)) return [];

    const params = translateAllParamTypes(cursor, context);

    return [
        // remove semicolon from the end with [0..$-1]
        `extern(D) ` ~ functionDecl(cursor, context, operatorSpellingD(cursor, context), Yes.names)[0..$-1],
        `{`,
        `    return ` ~ operatorSpellingCpp(cursor) ~ `(` ~ params.length.iota.map!(a => text("arg", a)).join(", ") ~ `);`,
        `}`,
    ];
}

private bool isSupportedOperator(in from!"clang".Cursor cursor) @safe nothrow {
    import std.algorithm: map, canFind;

    if(!isOperator(cursor)) return false;

    const cppOperator = cursor.spelling[OPERATOR_PREFIX.length .. $];
    const unsupportedSpellings = [`!`, `,`, `&&`, `||`, `->`, `->*`];
    if(unsupportedSpellings.canFind(cppOperator)) return false;

    if(isUnaryOperator(cursor) && cppOperator == "&") return false;

     return true;
}

private bool isOperator(in from!"clang".Cursor cursor) @safe pure nothrow {
    import std.algorithm: startsWith;
    return cursor.spelling.startsWith(OPERATOR_PREFIX);
}


private string functionSpelling(in from!"clang".Cursor cursor,
                                ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.algorithm: startsWith;


    if(cursor.kind == Cursor.Kind.Constructor) return "this";
    if(cursor.kind == Cursor.Kind.Destructor) return "~this";

    if(cursor.spelling.startsWith(OPERATOR_PREFIX)) return operatorSpellingCpp(cursor);

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

    const cppOperator = cursor.spelling[OPERATOR_PREFIX.length .. $];

    if(cursor.kind == Cursor.Kind.ConversionFunction) {
        return `opCast(T: ` ~ returnType(cursor, context) ~ `)`;
    }

    if(cppOperator.length > 1 &&
       cppOperator[$-1] == '=' &&
       (cppOperator.length != 2 || !['=', '!', '<', '>'].canFind(cppOperator[0])))
        return `opOpAssign(string op: "` ~ cppOperator[0 .. $-1] ~ `")`;

    assert(isUnaryOperator(cursor) || isBinaryOperator(cursor));
    const dFunction = isBinaryOperator(cursor) ? "opBinary" : "opUnary";

    switch(cppOperator) {
        default: return dFunction ~ `(string op: "` ~ cppOperator ~ `")`;
        case "=": return `opAssign`;
        case "()": return `opCall`;
        case "[]": return `opIndex`;
        case "==": return `opEquals`;
    }
}

private bool isUnaryOperator(in from!"clang".Cursor cursor) @safe nothrow {
    import std.range: walkLength;
    return isOperator(cursor) && paramTypes(cursor).walkLength == 0;
}

private bool isBinaryOperator(in from!"clang".Cursor cursor) @safe nothrow {
    import std.range: walkLength;
    return isOperator(cursor) && paramTypes(cursor).walkLength == 1;
}


private string operatorSpellingCpp(in from!"clang".Cursor cursor)
    @safe
{
    import clang: Cursor;

    const operator = cursor.spelling[OPERATOR_PREFIX.length .. $];

    if(cursor.kind == Cursor.Kind.ConversionFunction) {
        // the first character will be a space
        return "oppCppCast_" ~ operator[1..$];
    }

    switch(operator) {
        default: throw new Exception("Unknown C++ spelling for operator '" ~ operator ~ "'");
        case   "+":  return `opCppPlus`;
        case   "-":  return `opCppMinus`;
        case  "++":  return `opCppIncrement`;
        case  "--":  return `opCppDecrement`;
        case   "*":  return `opCppMul`;
        case   "/":  return `opCppDiv`;
        case   "&":  return `opCppAmpersand`;
        case   "~":  return `opCppTilde`;
        case   "%":  return `opCppMod`;
        case   "^":  return `opCppCaret`;
        case   "|":  return `opCppPipe`;
        case   "=":  return `opCppAssign`;
        case  ">>":  return `opCppLShift`;
        case  "<<":  return `opCppRShift`;
        case  "->":  return `opCppArrow`;
        case   "!":  return `opCppBang`;
        case  "&&":  return `opCppAnd`;
        case  "||":  return `opCppOr`;
        case   ",":  return `opCppComma`;
        case "->*":  return `opCppArrowStar`;
        case  "+=":  return `opCppPlusAssign`;
        case  "-=":  return `opCppMinusAssign`;
        case  "*=":  return `opCppMulAssign`;
        case  "/=":  return `opCppDivAssign`;
        case  "%=":  return `opCppModAssign`;
        case  "^=":  return `opCppCaretAssign`;
        case  "&=":  return `opCppAmpersandAssign`;
        case  "|=":  return `opCppPipeAssign`;
        case ">>=":  return `opCppRShiftAssign`;
        case "<<=":  return `opCppLShiftAssign`;
        case "()":   return `opCppCall`;
        case "[]":   return `opCppIndex`;
        case "==":   return `opCppEquals`;
        case "!=":   return `opCppNotEquals`;
        case "<=":   return `opCppLessEquals`;
        case ">=":   return `opCppMoreEquals`;
        case  "<":   return `opCppLess`;
        case  ">":   return `opCppMore`;
        case " new": return `opCppNew`;
        case " new[]": return `opCppNewArray`;
        case " delete": return `opCppDelete`;
        case " delete[]": return `opCppDeleteArray`;
    }

    assert(0);
}


private string[] maybeMoveCtor(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{

    import dpp.cursor.dlang: maybeRename, maybePragma;
    import dpp.type: translate;
    import clang: Cursor, Type;

    if(!cursor.isMoveConstructor) return [];

    const paramType = () @trusted {  return paramTypes(cursor).front; }();

    return [
        maybePragma(cursor, context) ~ " this(" ~ translate(paramType.pointee, context) ~ "*);",
        "this(" ~ translate(paramType, context) ~ " wrapper) {",
        "    this(&wrapper.value);",
        "}",
    ];
}

// includes variadic params
private auto translateAllParamTypes(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    in from!"std.typecons".Flag!"names" names = from!"std.typecons".No.names,
)
    @safe
{
    import std.algorithm: endsWith, map;
    import std.array: array;
    import std.range: enumerate;
    import std.conv: text;

    // Here we used to check that if there were no parameters and the language is C,
    // then the correct translation in D would be (...);
    // However, that's not allowed in D. It just so happens that C production code
    // exists that doesn't bother with (void), so instead of producing something that
    // doesn't compile, we compromise and assume the user meant (void)

    const paramTypes = translateParamTypes(cursor, context).array;
    const isVariadic = cursor.type.spelling.endsWith("...)");
    const variadicParams = isVariadic ? ["..."] : [];

    return enumerate(paramTypes ~ variadicParams)
        .map!(a => names ? a[1] ~ text(" arg", a[0]) : a[1])
        .array;
}

auto translateParamTypes(in from!"clang".Cursor cursor,
                         ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.type: translate;
    import std.algorithm: map;
    import std.range: tee;
    import std.typecons: Yes;

    return paramTypes(cursor)
        .tee!((a){ context.log("Function Child: ", a); })
        .map!(a => translate(a, context, Yes.translatingFunction))
        ;
}

private auto paramTypes(in from!"clang".Cursor cursor)
    @safe
{
    import clang: Cursor;
    import std.algorithm: map, filter;

    return cursor
        .children
        .filter!(a => a.kind == Cursor.Kind.ParmDecl)
        .map!(a => a.type)
        ;
}
