/**
   The context the translation happens in, to avoid global variables
 */
module dpp.runtime.context;

// A function or global variable
struct Linkable {
    alias LineNumber = size_t;

    LineNumber lineNumber;
    string mangling;
}


/**
   Context for the current translation, to avoid global variables
 */
struct Context {

    import dpp.runtime.options: Options;
    import clang: Cursor;

    alias CursorHash = uint;
    alias SeenCursors = bool[CursorId];

    /**
       The lines of output so far. This is needed in order to fix
       any name collisions between functions or variables with aggregates
       such as structs, unions and enums.
     */
    private string[] lines;

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

    /**
       A linkable is a function or a global variable.
       We remember all the ones we saw here so that if there's a name clash
       with an aggregate we can come back and fix the declarations after
       the fact with  pragma(mangle).
     */
    Linkable[string] linkableDeclarations;

    /**
       All previously seen cursors
     */
    SeenCursors seenCursors;

    /// Command-line options
    Options options;


    this(Options options) @safe pure {
        this.options = options;
    }

    ref Context indent() @safe pure return {
        options = options.indent;
        return this;
    }

    string indentation() @safe @nogc pure const {
        return options.indentation;
    }

    void setIndentation(in string indentation) @safe pure {
        options.indentation = indentation;
    }

    void log(A...)(auto ref A args) const {
        import std.functional: forward;
        options.log(forward!args);
    }

    void indentLog(A...)(auto ref A args) const {
        import std.functional: forward;
        options.indent.log(forward!args);
    }

    bool debugOutput() @safe @nogc pure nothrow const {
        return options.debugOutput;
    }

    bool hasSeen(in Cursor cursor) @safe pure nothrow const {
        return cast(bool)(CursorId(cursor) in seenCursors);
    }

    void rememberCursor(in Cursor cursor) @safe pure nothrow {
        // EnumDecl can have no spelling but end up defining an enum anyway
        // See "it.compile.projects.double enum typedef"
        if(cursor.spelling != "" || cursor.kind == Cursor.Kind.EnumDecl)
            seenCursors[CursorId(cursor)] = true;
    }

    string translation() @safe pure nothrow const {
        import std.array: join;
        return lines.join("\n");
    }

    void writeln(in string line) @safe pure nothrow {
        lines ~= line.dup;
    }

    void writeln(in string[] lines) @safe pure nothrow {
        this.lines ~= lines;
    }

    // remember a function or variable declaration
    string rememberLinkable(in Cursor cursor) @safe pure nothrow {
        import dpp.cursor.dlang: maybeRename;
        const spelling = maybeRename(cursor, this);
        // since linkables produce one-line translations, the next
        // will be the linkable
        linkableDeclarations[spelling] = Linkable(lines.length, cursor.mangling);
        return spelling;
    }

    void fixLinkables() @safe pure {
        foreach(aggregate, _; aggregateDeclarations) {
            // if there's a name clash, fix it
            auto clashingLinkable = aggregate in linkableDeclarations;
            if(clashingLinkable) {
                resolveClash(lines[clashingLinkable.lineNumber], aggregate, clashingLinkable.mangling);
            }
        }
    }

    // find the last one we named, pop it off, and return it
    string popLastNickName() @safe pure {

        if(nickNames.length == 0) throw new Exception("No nickname to pop");

        auto ret = nickNames[$-1];
        nickNames = nickNames[0 .. $-1];
        return ret;
    }

    /** If unknown structs show up in functions or fields (as a pointer),
        define them now so the D file can compile
        See `it.c.compile.delayed`.
    */
    void declareUnknownStructs() @safe pure {
        foreach(name, _; fieldStructPointerSpellings) {
            if(name !in aggregateDeclarations) {
                log("Could not find '", name, "' in aggregate declarations, defining it");
                writeln("struct " ~ name ~ ";");
                aggregateDeclarations[name] = true;
            }
        }
    }

}

private void resolveClash(ref string line, in string spelling, in string mangling) @safe pure {
    import dpp.cursor.dlang: pragmaMangle, rename;
    import std.string: replace;
    line = pragmaMangle(mangling) ~ line.replace(spelling, rename(spelling));
}


// to identify a cursor
private struct CursorId {
    import clang: Cursor, Type;

    string cursorSpelling;
    Cursor.Kind cursorKind;
    string typeSpelling;
    Type.Kind typeKind;

    this(in Cursor cursor) @safe pure nothrow {
        cursorSpelling = cursor.spelling;
        cursorKind = cursor.kind;
        typeSpelling = cursor.type.spelling;
        typeKind = cursor.type.kind;
    }
}
