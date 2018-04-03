/**
   The context the translation happens in, to avoid global variables
 */
module include.runtime.context;

import include.from;

/**
   Context for the current translation, to avoid global variables
 */
struct Context {

    import include.runtime.options: Options;

    alias CursorHash = uint;

    this(Options options) @safe pure {
        this.options = options;
    }

    /**
       Structs can be anonymous in C, and it's even common
       to typedef them to a name. We come up with new names
       that we track here so as to be able to properly transate
       those typedefs.
    */
    string[CursorHash] cursorNickNames;

    // FIXME - there must be a better way
    /// Used to find the last nickname we coined (e.g. "_Anonymous_1")
    string[] nickNames;

    /**
       Remembers the seen struct pointers so that if any are undeclared in C,
       we do so in D at the end.
     */
    bool[string] fieldStructPointerSpellings;

    /**
       All the aggregates that have been declared
     */
    bool[string] aggregateDeclarations;

    /// Command-line options
    Options options;

    ref Context indent() @safe pure return {
        options = options.indent;
        return this;
    }

    void log(A...)(auto ref A args) const {
        import std.functional: forward;
        options.log(forward!args);
    }

    bool debugOutput() @safe @nogc pure nothrow const {
        return options.debugOutput;
    }
}


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
