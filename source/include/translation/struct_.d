/**
   Struct translations.
 */
module include.translation.struct_;

import include.from;

string[] translateStruct(from!"clang".Cursor struct_) @safe {
    import clang: Cursor;

    assert(struct_.kind == Cursor.Kind.StructDecl);

    string[] ret;

    ret ~= `struct Foo {`;
    foreach(field; struct_) {
        ret ~= translateField(field);
    }
    ret ~= `}`;

    return ret;
}

string translateField(in from!"clang".Cursor field) @safe pure {
    import include.translation.type: translate;
    import clang: Cursor;
    import std.conv: text;

    assert(field.kind == Cursor.Kind.FieldDecl);
    const type = translate(field.type);
    const name = field.spelling;
    return text(type, " ", name, ";");
}
