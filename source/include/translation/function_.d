/**
   Function translations.
 */
module include.translation.function_;

import include.from;

string[] translateFunction(in from!"clang".Cursor function_,
                           ref from!"include.runtime.context".Context context)
    @safe
{
    import include.translation.type: translate;
    import clang: Cursor, Language;
    import std.array: join;
    import std.conv: text;
    import std.algorithm: endsWith;
    import std.typecons: Yes;
    import std.array: array;
    import std.range: chain, only;

    assert(function_.kind == Cursor.Kind.FunctionDecl);

    const returnType = translate(function_.returnType, context, Yes.translatingFunction);
    context.indent.log("Function return type: ", returnType);
    const isVariadic =
        function_.type.spelling.endsWith("...)") ||
        (function_.language == Language.C && function_.type.spelling.endsWith("()"));
    const variadicParams = isVariadic ? "..." : "";
    const allParams = paramTypes(function_, context.indent).array ~ variadicParams;

    return [
        text(returnType, " ", function_.spelling, "(", allParams.join(", "), ");")
    ];
}

auto paramTypes(in from!"clang".Cursor function_,
                ref from!"include.runtime.context".Context context)
    @safe
{
    import include.translation.type: translate;
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
