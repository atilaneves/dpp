/**
   Function translations.
 */
module dpp.cursor.function_;

import dpp.from;

private enum OPERATOR_PREFIX = "operator";

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
        cursor.kind == Cursor.Kind.Destructor
    );

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
    const const_ = cursor.type.spelling.endsWith(") const") ? " const" : "";

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

    auto ret = cursor.kind == Cursor.Kind.Constructor || cursor.kind == Cursor.Kind.Destructor
        ? ""
        : translate(cursor.returnType, context, Yes.translatingFunction);

    context.setIndentation(indentation);
    context.log("Function return type (translated): ", ret);

    return ret;
}

private string[] maybeOperator(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{
    import std.algorithm: startsWith, map;
    import std.array: join;
    import std.typecons: Yes;
    import std.range: iota;
    import std.conv: text;

    if(!cursor.spelling.startsWith(OPERATOR_PREFIX)) return [];

    const params = translateAllParamTypes(cursor, context);

    return [
        // remove semicolon from the end with [0..$-1]
        `extern(D)` ~ functionDecl(cursor, context, operatorSpellingD(cursor), Yes.names)[0..$-1],
        `{`,
        `    return ` ~ operatorSpellingCpp(cursor) ~ `(` ~ params.length.iota.map!(a => text("arg", a)).join(", ") ~ `);`,
        `}`,
    ];
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

private string operatorSpellingD(in from!"clang".Cursor cursor)
    @safe
{
    const operator = cursor.spelling[OPERATOR_PREFIX.length .. $];

    switch(operator) {
        default: throw new Exception("Unkown operator " ~ operator);
        case "+": return `opBinary(string op: "` ~ operator ~ `")`;
    }

    assert(0);
}

private string operatorSpellingCpp(in from!"clang".Cursor cursor)
    @safe
{
    const operator = cursor.spelling[OPERATOR_PREFIX.length .. $];

    switch(operator) {
        default: throw new Exception("Unkown operator " ~ operator);
        case "+": return `opCppPlus`;
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
    import std.array: array;

    if(cursor.kind == Cursor.Kind.Constructor) {
        auto paramTypes = () @trusted {  return paramTypes(cursor).array; }();
        if(paramTypes.length == 1 && paramTypes[0].kind == Type.Kind.RValueReference) {
            context.log("*** type: ", paramTypes[0]);
            return [
                maybePragma(cursor, context) ~ " this(" ~ translate(paramTypes[0].pointee, context) ~ "*);",
                "this(" ~ translate(paramTypes[0], context) ~ " wrapper) {",
                "    this(&wrapper.value);",
                "}",
            ];
        }
    }

    return [];
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
