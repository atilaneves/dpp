/**
   Enum translation
 */
module include.translation.enum_;

import include.from;

string[] translateEnumConstant(in from!"clang".Cursor cursor) @safe pure {
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.EnumConstantDecl);
    return [cursor.spelling ~ ","];
}
