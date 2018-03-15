/**
   Function translations.
 */
module include.translation.function_;

import include.from;

string[] translateFunction(in from!"clang".Cursor function_) @safe pure {
    import include.translation.type: translate;
    import clang: Cursor;
    import std.array: join;
    import std.conv: text;
    import std.algorithm: map, filter;
    import std.range: tee;
    version(unittest) import unit_threaded.io: writelnUt;

    assert(function_.kind == Cursor.Kind.FunctionDecl);

    const returnType = translate(function_.returnType);
    auto paramTypes = function_
        .children
        .tee!((a){ version(unittest) debug writelnUt("    Function Child: ", a); })
        .filter!(a => a.kind == Cursor.Kind.ParmDecl)
        .map!(a => translate(a.type))
        ;

    return [
        text(returnType, " ", function_.spelling, "(", paramTypes.join(", "), ");"),
    ];
}
