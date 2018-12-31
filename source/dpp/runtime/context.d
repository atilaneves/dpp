/**
   The context the translation happens in, to avoid global variables
 */
module dpp.runtime.context;
import dpp.from;

alias LineNumber = size_t;

// A function or global variable
struct Linkable {
    LineNumber lineNumber;
    string mangling;
}

enum Language {
    C,
    Cpp,
}

private string readAsString(string filename) @trusted
{
	static import std.file;
	return cast(string)(std.file.read(filename));
}

string[] readHeaderBlacklistFile(string filename) @safe
{
	static import std.file;
	import std.string:splitLines,strip;
	import std.array:array;
	import std.algorithm:map,filter,startsWith;

	auto lines = readAsString(filename)
			.splitLines
			.map!(line=>line.strip)
			.array
			.filter!(l=>l.length>0 && !l.startsWith("//"))
			.array;
	return lines;
}
struct TypeRemapping
{
	string originalType;
	string replacementType;
	bool addFirstSizeOfArgument;
	bool isRegex;
}

private enum BackQuote='`';

private bool originalTypeIsRegex(string typeName) pure @trusted
{
	return (typeName.length>2 && typeName[0]==BackQuote  && typeName[$-1] ==BackQuote);
}

string stripBackQuotes(string typeName) pure @safe
{
	import std.string:replace;
	return typeName.replace([BackQuote],"");
}

private TypeRemapping readTypeRemapping(string line) @safe
{
	import std.exception:enforce;
	import std.string:strip,toUpper,split;
	import std.array:array;
	import std.algorithm:map;

	TypeRemapping ret;
	auto cols = line.split(',')
			.map!(col=>col.strip)
			.array;
	enforce(cols.length>=2);
	auto originalType = cols[0];
	ret.isRegex = originalTypeIsRegex(originalType);
	ret.originalType = originalType.stripBackQuotes;
	ret.replacementType = cols[1];
	ret.addFirstSizeOfArgument = (cols.length>2 && (cols[2].toUpper =="Y" || cols[2].toUpper=="TRUE"));
	return ret;
}

private TypeRemapping[] readTypeRemappingsFile(string filename) @safe
{
	static import std.file;
	import std.string:splitLines,strip,split,toUpper;
	import std.array:array;
	import std.algorithm:map,filter,startsWith;

	auto lines = readAsString(filename)
			.splitLines
			.map!(line=>line.strip)
			.array
			.filter!(l=>l.length>0 && !l.startsWith("//"))
			.array
			.map!(line => readTypeRemapping(line))
			.array;
	return lines;
}

private bool isOpaqueType(string typeName) pure @safe
{
	import std.string:toLower;
	return (typeName.toLower =="opaque");
}

// wtf Map and Filter don't return InputRanges?
auto safeArray(Range)(Range range) @trusted // because filter is system
if (from!"std.range".isInputRange!Range || is(Range==FilterResult) || is(Range==MapResult))
{
	import std.array:Appender;
	alias T = from!"std.range".ElementType!(Range);
	Appender!(T[]) ret;
	foreach(ref e;range)
		ret.put(e);
	return ret.data;
}

private string[] opaqueTypes(TypeRemapping[] remappings) @safe
{
	import std.algorithm:filter,map;
	import std.array:array;
	return remappings.filter!(remappings => remappings.replacementType.isOpaqueType)
			.map!(remapping => remapping.originalType)
			.safeArray;
}

private const(TypeRemapping)[] nonOpaqueTypeRemappings(const scope TypeRemapping[] typeRemappings) @safe
{
	import std.algorithm:filter,map;
	import std.array:array;
	return typeRemappings
		.filter!(type => !type.replacementType.isOpaqueType)
		.safeArray;
}


/**
   Context for the current translation, to avoid global variables
 */
struct Context {

    import dpp.runtime.options: Options;
    import clang: Cursor;

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
       that we track here so as to be able to properly translate
       those typedefs.
    */
    private string[Cursor.Hash] cursorNickNames;

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
    string typeRemappingsFile;
    string headerBlacklistFile;

    const(TypeRemapping)[] typeRemappings;
    alias RegexT = typeof(from!"std.regex".regex("*"));
    RegexT[string] typeRemappingsRegex;

    string[] opaqueTypes;
    string[] headerBlacklists;
	    
    alias dgMatch = (string s, RegexT r) @system
	    		{
				auto match = from!"std.regex".matchFirst(s,r);
				return match? match.hit.idup : "";
			};

    string getRegexHit(const(string) originalType, const(string) tryType) @trusted pure
    {
	    import std.regex:matchFirst;
	    auto f = assumePure(dgMatch);
	    auto p = originalType in typeRemappingsRegex;
	    return (p is null) ? "" : f(tryType,*p);
    }

    string remapType(string typeName) @safe pure
    {
	    import std.string:replace;
	    import std.regex:matchFirst;
	    string ret = typeName;
	    foreach(ref t;typeRemappings)
	    {
		auto originalType = (!t.isRegex) ?  t.originalType : getRegexHit(t.originalType,typeName);
	    	ret=ret.replace(originalType,t.replacementType);
	    }
	    return ret;
    }
	    
    bool isTypeBlobSubstituted(string typeName) @safe pure
    {
	    import std.regex:matchFirst;
	    import std.algorithm:canFind;
	    foreach(ref opaqueType;opaqueTypes)
	    {
		auto hit = (opaqueType in typeRemappingsRegex) ? (getRegexHit(opaqueType,typeName).length>0) : (typeName.canFind(opaqueType));
		if (hit)
			return true;
	    }
	    return false;
    }
    bool isPathBlackListed(string path) @safe pure
    {
	    import std.algorithm:canFind;

	    //TODO - add regex later
	    foreach(headerBlacklist;headerBlacklists)
	    {
		    if(path.canFind(headerBlacklist))
			    return true;
	    }
	    return false;
    }
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

    Language language;

    this(Options options, in Language language,string typeRemappingsFile, string headerBlacklistFile) @safe {
	import std.array:array;
	import std.algorithm:filter;
	import std.regex:regex;
        this.options = options;
        this.language = language;
	auto typeRemappings = readTypeRemappingsFile(typeRemappingsFile);
	this.opaqueTypes = typeRemappings.opaqueTypes;
	this.typeRemappings = typeRemappings.nonOpaqueTypeRemappings;
	this.headerBlacklists = readHeaderBlacklistFile(headerBlacklistFile);
	foreach(typeRemapping;typeRemappings.filter!(t=>t.isRegex))
		this.typeRemappingsRegex[typeRemapping.originalType] = regex(typeRemapping.originalType);
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
        if(cursor.kind == Cursor.Kind.Namespace) return false;
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

private auto assumePure(T)(T t)
if (from!"std.traits".isFunctionPointer!T || from!"std.traits".isDelegate!T)
{
	import std.traits:functionAttributes, FunctionAttribute,functionLinkage,SetFunctionAttributes;
	enum attrs = functionAttributes!T | FunctionAttribute.pure_;
	return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}
