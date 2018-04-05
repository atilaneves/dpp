/**
   Function translations.
 */
module include.cursor.function_;

import include.from;

string[] translateFunction(in from!"clang".Cursor function_,
                           ref from!"include.runtime.context".Context context)
    @safe
{
    import include.cursor.dlang: maybeRename, maybePragma;
    import include.type: translate;
    import clang: Cursor, Language;
    import std.array: join;
    import std.conv: text;
    import std.algorithm: endsWith;
    import std.typecons: Yes;
    import std.array: array;
    import std.range: chain, only;

    assert(function_.kind == Cursor.Kind.FunctionDecl);

    const indentation = context.indentation;
    context.log("Function return type (raw):        ", function_.returnType);
    const returnType = translate(function_.returnType, context, Yes.translatingFunction);
    context.setIndentation(indentation);
    context.log("Function return type (translated): ", returnType);

    // Here we used to check that if there were no parameters and the language is C,
    // then the correct translation in D would be (...);
    // However, that's not allowed in D. It just so happens that C production code
    // exists that doesn't bother with (void), so instead of producing something that
    // doesn't compile, we compromise and assume the user meant (void)

    const isVariadic = function_.type.spelling.endsWith("...)");
    const variadicParams = isVariadic ? "..." : "";
    const allParams = paramTypes(function_, context).array ~ variadicParams;

    const spelling = maybeRename(function_, context);

    return [
        maybePragma(function_, context) ~
        text(returnType, " ", spelling, "(", allParams.join(", "), ");")
    ];
}

auto paramTypes(in from!"clang".Cursor function_,
                ref from!"include.runtime.context".Context context)
    @safe
{
    import include.type: translate;
    import clang: Cursor;
    import std.algorithm: map, filter;
    import std.range: tee;
    import std.typecons: Yes;

    return function_
        .children
        .tee!((a){ context.log("Function Child: ", a); })
        .filter!(a => a.kind == Cursor.Kind.ParmDecl)
        .map!(a => translate(a.type, context, Yes.translatingFunction))
        ;
}
