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
    import dpp.type: translate;
    import clang: Cursor, Language;
    import std.array: join;
    import std.conv: text;
    import std.algorithm: endsWith;
    import std.typecons: Yes;
    import std.array: array;
    import std.range: chain, only;

    assert(cursor.kind == Cursor.Kind.FunctionDecl);

    const indentation = context.indentation;
    context.log("Function return type (raw):        ", cursor.returnType);
    const returnType = translate(cursor.returnType, context, Yes.translatingFunction);
    context.setIndentation(indentation);
    context.log("Function return type (translated): ", returnType);

    // Here we used to check that if there were no parameters and the language is C,
    // then the correct translation in D would be (...);
    // However, that's not allowed in D. It just so happens that C production code
    // exists that doesn't bother with (void), so instead of producing something that
    // doesn't compile, we compromise and assume the user meant (void)

    const isVariadic = cursor.type.spelling.endsWith("...)");
    const variadicParams = isVariadic ? "..." : "";
    const allParams = translateParamTypes(cursor, context).array ~ variadicParams;

    const spelling = context.rememberLinkable(cursor);

    return [
        maybePragma(cursor, context) ~
        text(returnType, " ", spelling, "(", allParams.join(", "), ");")
    ];
}

auto translateParamTypes(in from!"clang".Cursor cursor,
                         ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.type: translate;
    import clang: Cursor;
    import std.algorithm: map, filter;
    import std.range: tee;
    import std.typecons: Yes;

    return cursor
        .children
        .tee!((a){ context.log("Function Child: ", a); })
        .filter!(a => a.kind == Cursor.Kind.ParmDecl)
        .map!(a => translate(a.type, context, Yes.translatingFunction))
        ;
}
