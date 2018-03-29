/**
   The context the translation happens in, to avoid global variables
 */
module include.runtime.context;

import include.from;


// to identify a cursor
private struct CursorId {
    import clang: Cursor;

    string spelling;
    Cursor.Kind kind;

    this(in Cursor cursor) @safe pure nothrow {
        spelling = cursor.spelling;
        kind = cursor.kind;
    }
}

alias SeenCursors = bool[CursorId];


bool hasSeen(in SeenCursors cursors, in from!"clang".Cursor cursor) @safe pure nothrow {
    return cast(bool)(CursorId(cursor) in cursors);
}

void remember(ref SeenCursors cursors, in from!"clang".Cursor cursor) @safe pure nothrow {
    if(cursor.spelling != "")
        cursors[CursorId(cursor)] = true;
}
