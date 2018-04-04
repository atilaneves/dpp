/**
   Enum translation
 */
module include.cursor.enum_;

import include.from;

string[] translateEnumConstant(in from!"clang".Cursor cursor,
                               ref from!"include.runtime.context".Context context)
    @safe pure
{
    import clang: Cursor;
    import std.conv: text;

    assert(cursor.kind == Cursor.Kind.EnumConstantDecl);
    return [cursor.spelling ~ ` = ` ~ text(cursor.enumConstantValue) ~ `, `];
}
