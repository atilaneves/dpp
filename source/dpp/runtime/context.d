/**
   The context the translation happens in, to avoid global variables
 */
module dpp.runtime.context;

alias LineNumber = size_t;

// A function or global variable
struct Linkable {
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
    private string[CursorHash] cursorNickNames;

    // FIXME - there must be a better way
    /// Used to find the last nickname we coined (e.g. "_Anonymous_1")
    private string[] nickNames;

    /**
       Remembers the seen struct pointers so that if any are undeclared in C,
       we do so in D at the end.
     */
    private bool[string] fieldStructSpellings;

    /**
       Remembers the field spellings in aggregates in case we need to change any
       of them.
     */
    private LineNumber[string] fieldDeclarations;

    /**
       All the aggregates that have been declared
     */
    private bool[string] _aggregateDeclarations;

    /**
       A linkable is a function or a global variable.  We remember all
       the ones we saw here so that if there's a name clash we can
       come back and fix the declarations after the fact with
       pragma(mangle).
     */
    private Linkable[string] linkableDeclarations;

    /**
       All the function-like macros that have been declared
     */
    private bool[string] functionMacroDeclarations;

    /**
       Remember all the macros already defined
     */
    private bool[string] macros;

    /**
       All previously seen cursors
     */
    private SeenCursors seenCursors;

    /// Command-line options
    Options options;

    /*
      Remember all declared types so that C-style casts can be recognised
     */
    private string[] _types = [
        `void ?\*`,
        `char`, `unsigned char`, `signed char`, `short`, `unsigned short`,
        `int`, `unsigned`, `unsigned int`, `long`, `unsigned long`, `long long`,
        `unsigned long long`, `float`, `double`, `long double`,
    ];

    /// to generate unique names
    private int _anonymousIndex;

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
        import dpp.translation.dlang: maybeRename;
        const spelling = maybeRename(cursor, this);
        // since linkables produce one-line translations, the next
        // will be the linkable
        linkableDeclarations[spelling] = Linkable(lines.length, cursor.mangling);
        return spelling;
    }

    void fixNames() @safe pure {
        declareUnknownStructs;
        fixLinkables;
        fixFields;
    }

    void fixLinkables() @safe pure {
        foreach(declarations; [_aggregateDeclarations, functionMacroDeclarations]) {
            foreach(name, _; declarations) {
                // if there's a name clash, fix it
                auto clashingLinkable = name in linkableDeclarations;
                if(clashingLinkable) {
                    resolveClash(lines[clashingLinkable.lineNumber], name, clashingLinkable.mangling);
                }
            }
        }
    }

    void fixFields() @safe pure {

        import dpp.translation.dlang: pragmaMangle, rename;
        import std.string: replace;

        foreach(spelling, lineNumber; fieldDeclarations) {
            if(spelling in _aggregateDeclarations) {
                lines[lineNumber] = lines[lineNumber]
                    .replace(spelling ~ `;`, rename(spelling, this) ~ `;`);
            }
        }
    }

    /**
       Tells the context to remember a struct type encountered in an aggregate field.
       Typically this will be a pointer to a structure but it could also be the return
       type or parameter types of a function pointer field.
     */
    void rememberFieldStruct(in string typeSpelling) @safe pure {
        fieldStructSpellings[typeSpelling] = true;
    }

    /**
       In C it's possible for a struct field name to have the same name as a struct
       because of elaborated names. We remember them here in case we need to fix them.
     */
    void rememberField(in string spelling) @safe pure {
        fieldDeclarations[spelling] = lines.length;
    }

    /**
       Remember this aggregate cursor
     */
    void rememberAggregate(in Cursor cursor) @safe pure {
        const spelling = spellingOrNickname(cursor);
        _aggregateDeclarations[spelling] = true;
        rememberType(spelling);
    }

    // find the last one we named, pop it off, and return it
    string popLastNickName() @safe pure {

        if(nickNames.length == 0) {
            // this might happen with `enum { one, two } var;`
            // We need the typename to declare `var` with but the translation only comes
            auto ret = newAnonymousTypeName;
            --_anonymousIndex; // make sure we return the same name next time
            return ret;
        }

        auto ret = nickNames[$-1];
        nickNames = nickNames[0 .. $-1];
        return ret;
    }

    /**
       If unknown structs show up in functions or fields (as a pointer),
        define them now so the D file can compile
        See `it.c.compile.delayed`.
    */
    void declareUnknownStructs() @safe pure {
        foreach(name, _; fieldStructSpellings) {
            if(name !in _aggregateDeclarations) {
                log("Could not find '", name, "' in aggregate declarations, defining it");
                writeln("struct " ~ name ~ ";");
                _aggregateDeclarations[name] = true;
            }
        }
    }

    const(typeof(_aggregateDeclarations)) aggregateDeclarations() @safe pure nothrow const {
        return _aggregateDeclarations;
    }

    /// return the spelling if it exists, or our made-up nickname for it if not
    string spellingOrNickname(in Cursor cursor) @safe pure {
        import dpp.translation.dlang: rename, isKeyword;
        if(cursor.spelling == "") return nickName(cursor);
        return cursor.spelling.isKeyword ? rename(cursor.spelling, this) : cursor.spelling;
    }

    private string nickName(in Cursor cursor) @safe pure {
        if(cursor.hash !in cursorNickNames) {
            auto nick = newAnonymousTypeName;
            nickNames ~= nick;
            cursorNickNames[cursor.hash] = nick;
        }

        return cursorNickNames[cursor.hash];
    }

    private string newAnonymousTypeName() @safe pure {
        import std.conv: text;
        return text("_Anonymous_", _anonymousIndex++);
    }

    string newAnonymousMemberName() @safe pure {
        import std.string: replace;
        return newAnonymousTypeName.replace("_A", "_a");
    }

    private void resolveClash(ref string line, in string spelling, in string mangling) @safe pure const {
        import dpp.translation.dlang: pragmaMangle;
        line = `    ` ~ pragmaMangle(mangling) ~ replaceSpelling(line, spelling);
    }

    private string replaceSpelling(in string line, in string spelling) @safe pure const {
        import dpp.translation.dlang: rename;
        import std.array: replace;
        return line
            .replace(spelling ~ `;`, rename(spelling, this) ~ `;`)
            .replace(spelling ~ `(`, rename(spelling, this) ~ `(`)
            ;
    }

    void rememberType(in string type) @safe pure nothrow {
        _types ~= type;
    }

    /// Matches a C-type cast
    auto castRegex() @safe const {
        import std.array: join, array;
        import std.regex: regex;
        import std.algorithm: map;
        import std.range: chain;

        // const and non const versions of each type
        const typesConstOpt = _types.map!(a => `(?:const )?` ~ a).array;

        const typeSelectionStr =
            chain(typesConstOpt,
                  // pointers thereof
                  typesConstOpt.map!(a => a ~ ` ?\*`))
            .join("|");

        // parens and a type inside, where "a type" is any we know about
        const regexStr = `\(( *?(?:` ~ typeSelectionStr ~ `) *?)\)`;

        return regex(regexStr);
    }

    void rememberMacro(in Cursor cursor) @safe pure {
        macros[cursor.spelling] = true;
        if(cursor.isMacroFunction)
            functionMacroDeclarations[cursor.spelling] = true;
    }

    bool macroAlreadyDefined(in Cursor cursor) @safe pure const {
        return cast(bool) (cursor.spelling in macros);
    }
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
