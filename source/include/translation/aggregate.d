/**
   Translate aggregates
 */
module include.translation.aggregate;

import include.from;

/**
   Structs can be anomymous in C, and it's even common
   to typedef them to a name. We come up with new names
   that we track here so as to be able to properly transate
   those typedefs.
 */
private shared string[from!"clang.c.index".CXCursor] gNicknames;


string[] translateStruct(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.StructDecl);
    return translateAggregate(cursor, "struct");
}

string[] translateUnion(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.UnionDecl);
    return translateAggregate(cursor, "union");
}

string[] translateEnum(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.EnumDecl);
    return translateAggregate(cursor, "enum");
}

// not pure due to Cursor.opApply not being pure
string[] translateAggregate(
    in from!"clang".Cursor cursor,
    in string keyword,
)
    @safe
{
    import include.translation.unit: translate;
    import clang: Cursor;
    import std.algorithm: map;
    import std.array: array;

    string[] lines;

    lines ~= keyword ~ ` ` ~ spellingOrNickname(cursor);
    lines ~= `{`;

    foreach(member; cursor) {
        lines ~= translate(member).map!(a => "    " ~ a).array;
    }

    lines ~= `}`;

    return lines;
}


string[] translateField(in from!"clang".Cursor field) @safe pure {

    import include.translation.type: translate;
    import clang: Cursor;
    import std.conv: text;
    version(unittest) import unit_threaded.io: writelnUt;

    assert(field.kind == Cursor.Kind.FieldDecl,
           text("Field of wrong kind: ", field));

    version(unittest) debug writelnUt("    Field: ", field);
    return [text(translate(field.type), " ", field.spelling, ";")];
}

// return the spelling if it exists, or our made-up nickname for it
// if not
package string spellingOrNickname(in from!"clang".Cursor cursor) @safe {

    import std.conv: text;

    static int index;

    if(cursor.spelling != "") return cursor.spelling;

    if(cursor.cx !in gNicknames) {
        gNicknames[cursor.cx] = text("_Anonymous_", index++);
    }

    return gNicknames[cursor.cx];
}
