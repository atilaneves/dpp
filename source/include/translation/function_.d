/**
   Function translations.
 */
module include.translation.function_;

import include.from;

string[] translateFunction(in from!"clang".Cursor function_,
                           in from!"include.runtime.options".Options options =
                                  from!"include.runtime.options".Options())
    @safe
{
    import include.translation.type: translate;
    import clang: Cursor;
    import std.array: join;
    import std.conv: text;
    import std.algorithm: map, filter, endsWith;
    import std.range: tee;
    import std.typecons: Yes;

    assert(function_.kind == Cursor.Kind.FunctionDecl);

    const returnType = translate(function_.returnType, Yes.translatingFunction, options);
    options.indent.log("Function return type: ", returnType);
    auto paramTypes = function_
        .children
        .tee!((a){ options.indent.log("Function Child: ", a); })
        .filter!(a => a.kind == Cursor.Kind.ParmDecl)
        .map!(a => translate(a.type, Yes.translatingFunction, options))
        ;
    const variadicParams = function_.type.spelling.endsWith("...)") ? ", ..." : "";

    return [
        text(returnType, " ", function_.spelling, "(", paramTypes.join(", "), variadicParams, ");"),
    ];
}
