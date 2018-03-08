/**
   Function translations.
 */
module include.translation.function_;

import include.from;

string[] translateFunction(in from!"clang".Cursor function_) @safe pure {
    import clang: Cursor;
    import std.array: join;
    import std.conv: text;
    import std.algorithm: startsWith;
    import std.array: replace;
    version(unittest) import unit_threaded.io: writelnUt;

    assert(function_.kind == Cursor.Kind.FunctionDecl);

    version(unittest) debug writelnUt("Function: ", function_);

    string returnType = function_.returnType.spelling;
    if(returnType.startsWith("struct ")) returnType = returnType.replace("struct ", "");

    const types = ["Foo*", "Foo*"];

    return [
        text(returnType, " ", function_.spelling, "(", types.join(", "), ");"),
    ];
}
