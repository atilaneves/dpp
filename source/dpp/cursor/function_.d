/**
   Function translations.
 */
module dpp.cursor.function_;

import dpp.from;

string[] translateFunction(in from!"clang".Cursor cursor,
                           ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.cursor.dlang: maybeRename, maybePragma;
    import dpp.cursor.aggregate: maybeRememberStructs;
    import dpp.type: translate;
    import clang: Cursor, Language;
    import std.array: join, array;
    import std.conv: text;
    import std.algorithm: endsWith;
    import std.typecons: Yes;

    assert(cursor.kind == Cursor.Kind.FunctionDecl ||
           cursor.kind == Cursor.Kind.CXXMethod ||
           cursor.kind == Cursor.Kind.Constructor
   );

    const indentation = context.indentation;
    context.log("Function return type (raw):        ", cursor.type.returnType);

    const returnType = cursor.kind == Cursor.Kind.Constructor
        ? ""
        : translate(cursor.returnType, context, Yes.translatingFunction);

    context.setIndentation(indentation);
    context.log("Function return type (translated): ", returnType);

    maybeRememberStructs(paramTypes(cursor), context);

    // Here we used to check that if there were no parameters and the language is C,
    // then the correct translation in D would be (...);
    // However, that's not allowed in D. It just so happens that C production code
    // exists that doesn't bother with (void), so instead of producing something that
    // doesn't compile, we compromise and assume the user meant (void)

    const paramTypes = translateParamTypes(cursor, context).array;
    const isVariadic = cursor.type.spelling.endsWith("...)");
    const variadicParams = isVariadic ? "..." : "";
    const allParams = paramTypes ~ variadicParams;

    const spelling = cursor.kind == Cursor.Kind.Constructor
        ? "this"
        : context.rememberLinkable(cursor);

    return [
        maybePragma(cursor, context) ~
        text(returnType, " ", spelling, "(", allParams.join(", "), ") @nogc nothrow;")
    ];
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
