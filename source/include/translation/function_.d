/**
   Function translations.
 */
module include.translation.function_;

import include.from;

string[] translateFunction(in from!"clang".Cursor function_) @safe pure {
    import clang: Cursor;
    import std.array: join;
    import std.conv: text;

    assert(function_.kind == Cursor.Kind.FunctionDecl);

    const returnType = "Foo";
    const name = "addFoos";
    const types = ["Foo*", "Foo*"];
    return [text(returnType, " ", name, "(", types.join(", "), ");")];
}
