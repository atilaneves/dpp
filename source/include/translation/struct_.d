/**
   Struct translations.
 */
module include.translation.struct_;

import include.from;

string[] translateStruct(in from!"clang".Cursor struct_) @safe {
    import include.translation.aggregate: translateAggregate;
    return translateAggregate(struct_, "struct", &translateField);
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
