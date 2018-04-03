module include.translation.variable;

import include.from;

string[] translateVariable(in from!"clang".Cursor cursor,
                           ref from!"include.runtime.context".Context context)
    @safe
{
    import include.translation.type: translate;
    import clang: Cursor;
    import std.conv: text;
    import std.typecons: No;

    assert(cursor.kind == Cursor.Kind.VarDecl);

    // variables can be declared multiple times in C but only one in D
    if(!cursor.isCanonical) return [];

    return [text("extern __gshared ",
                 translate(cursor.type, context, No.translatingFunction), " ", cursor.spelling, ";")];
}
