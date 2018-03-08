/**
   Translate aggregates
 */
module include.translation.aggregate;

import include.from;

string[] translateStruct(in from!"clang".Cursor struct_) @safe {
    import include.translation.aggregate: translateAggregate;
    return translateAggregate(struct_, "struct");
}

string[] translateUnion(in from!"clang".Cursor union_) @safe {
    import include.translation.aggregate: translateAggregate;
    return translateAggregate(union_, "union");
}

string[] translateAggregate(
    in from!"clang".Cursor cursor,
    in string keyword,
)
    @safe
{
    import clang: Cursor;
    import std.algorithm: map;
    import std.array: array;

    string[] lines;

    lines ~= keyword ~ ` ` ~ cursor.spelling;
    lines ~= `{`;

    foreach(member; cursor) {
        lines ~= translateMember(member).map!(a => "    " ~ a).array;
    }

    lines ~= `}`;

    return lines;
}

string[] translateMember(in from!"clang".Cursor member) @safe {
    import clang: Cursor;
    import std.conv: text;

    switch(member.kind) with(Cursor.Kind) {
        default:         throw new Exception(text("Unsupported kind for translateMember: ", member));
        case FieldDecl:  return translateField(member);
        case StructDecl: return "static" ~ translateStruct(member);
        case UnionDecl:  return "static" ~ translateStruct(member);
    }
}

string[] translateField(in from!"clang".Cursor field) @safe pure {

    import include.translation.type: translate;
    import clang: Cursor;
    import std.conv: text;
    version(unittest) import unit_threaded.io: writelnUt;

    assert(field.kind == Cursor.Kind.FieldDecl,
           text("Field of wrong kind: ", field));

    version(unittest) debug writelnUt("Field: ", field);
    return [text(translate(field.type), " ", field.spelling, ";")];
}
