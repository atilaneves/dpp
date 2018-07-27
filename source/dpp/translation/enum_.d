/**
   Enum translation
 */
module dpp.translation.enum_;

import dpp.from;

string[] translateEnumConstant(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context)
    @safe pure
{
    import clang: Cursor;
    import std.conv: text;

    assert(cursor.kind == Cursor.Kind.EnumConstantDecl);
    return [cursor.spelling ~ ` = ` ~ text(cursor.enumConstantValue) ~ `, `];
}
