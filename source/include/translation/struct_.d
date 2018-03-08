/**
   Struct translations.
 */
module include.translation.struct_;

import include.from;

string[] translateStruct(in from!"clang".Cursor struct_) @safe {
    import clang: Cursor;
    version(unittest) import unit_threaded.io: writelnUt;

    assert(struct_.kind == Cursor.Kind.StructDecl);

    version(unittest) writelnUt("Struct: ", struct_);

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
    version(unittest) import unit_threaded.io: writelnUt;

    assert(field.kind == Cursor.Kind.FieldDecl);

    version(unittest) debug writelnUt("Field: ", field);

    return text(translate(field.type), " ", field.spelling, ";");
}
