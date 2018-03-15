module include.translation.variable;

import include.from;

string[] translateVariable(in from!"clang".Cursor cursor,
                           in from!"include.runtime.options".Options options =
                                  from!"include.runtime.options".Options())
    @safe pure
{
    import include.translation.type: translate;
    import clang: Cursor;
    import std.conv: text;

    assert(cursor.kind == Cursor.Kind.VarDecl);

    return [text("__gshared ", translate(cursor.type, options), " ", cursor.spelling, ";")];
}
