/**
   Function translations.
 */
module include.translation.function_;

import include.from;

string[] translateFunction(in from!"clang".Cursor function_) @safe /*pure*/ {
    import include.translation.type: cleanType;
    import clang: Cursor;
    import std.array: join;
    import std.conv: text;
    import std.algorithm: startsWith;
    import std.array: replace;
    version(unittest) import unit_threaded.io: writelnUt;

    assert(function_.kind == Cursor.Kind.FunctionDecl);

    version(unittest) debug writelnUt("Function: ", function_);

    const returnType = function_.returnType.spelling.cleanType;
    string[] paramTypes;

    foreach(child; function_) {

        version(unittest) debug writelnUt("    Function Child: ", child);

        if(child.kind == Cursor.Kind.ParmDecl)
            paramTypes ~= child.type.spelling.cleanType;
    }

    return [
        text(returnType, " ", function_.spelling, "(", paramTypes.join(", "), ");"),
    ];
}
