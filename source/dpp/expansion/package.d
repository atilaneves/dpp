/**
   Deals with expanding #include directives inline.
 */
module dpp.expansion;


import dpp.from;


/**
   Params:
       translUnitFileName = The file name with all #include directives to parse
       context = The translation context
       language = Whether it's a C or C++ file
       includePaths = The list of files to pass as -I options to clang
 */
void expand(in string translUnitFileName,
            ref from!"dpp.runtime.context".Context context,
            in string[] includePaths,
            in string file = __FILE__,
            in size_t line = __LINE__)
    @safe
{
    import dpp.translation.translation: translateTopLevelCursor;
    import dpp.runtime.context: Language;
    import dpp.runtime.context: Language, safeArray;
    import clang: Cursor;       import clang: Cursor;
    import dpp.translation.namespace:mergeNamespaces,chunk;
    import std.algorithm:filter,map;

    const extern_ = context.language == Language.Cpp ? "extern(C++)" : "extern(C)";
    context.writeln([extern_, "{"]);

    auto translationUnit = parseTU(translUnitFileName, context, includePaths);
    auto cursors = canonicalCursors(translationUnit);

    auto namespaceCursors = cursors
                            .filter!(cursor => cursor.kind == Cursor.Kind.Namespace)
                            .safeArray
                            .chunk
                            .map!(g => g.mergeNamespaces)
                            .safeArray;

    auto nonNamespaceCursors = cursors
                                .filter!(cursor => cursor.kind != Cursor.Kind.Namespace)
                                .safeArray;
 
      // logically the global namespace should come first, but that tends to have a lot
     // of garbage in it so it's easier to read when debugging if you start with namespaces
     foreach(cursor; namespaceCursors ~ nonNamespaceCursors) {
 
        if(context.hasSeen(cursor)) continue;
        context.rememberCursor(cursor);

        const indentation = context.indentation;
        const lines = translateTopLevelCursor(cursor, context, file, line);
        if(lines.length) context.writeln(lines);
        context.setIndentation(indentation);
    }

    context.writeln(["}", ""]);
    context.writeln("");
}


private from!"clang".TranslationUnit parseTU
    (
        in string translUnitFileName,
        ref from!"dpp.runtime.context".Context context,
        in string[] includePaths,
    )
    @safe
{
    import dpp.runtime.context: Language;
    import clang: parse, TranslationUnitFlags;
    import std.array: array;
    import std.algorithm: map;

    auto parseArgs =
        includePaths.map!(a => "-I" ~ a).array ~
        context.options.defines.map!(a => "-D" ~ a).array
        ;

    if(context.options.parseAsCpp || context.language == Language.Cpp)
        parseArgs ~= ["-xc++", "-std=c++14"];
    else
        parseArgs ~= "-xc";

    return parse(translUnitFileName,
                 parseArgs,
                 TranslationUnitFlags.DetailedPreprocessingRecord);
}

/**
   In C there can be several declarations and one definition of a type.
   In D we can have only ever one of either. There might be multiple
   cursors in the translation unit that all refer to the same canonical type.
   Unfortunately, the canonical type is orthogonal to which cursor is the actual
   definition, so we prefer to find the definition if it exists, and if not, we
   take the canonical declaration so as to not repeat ourselves in D.

   Returns: range of clang.Cursor
*/
private auto canonicalCursors(from!"clang".TranslationUnit translationUnit) @safe {

    import clang: Cursor;
    import std.algorithm: filter, partition;

    // Filter out "ghosts" (useless repeated cursors).
    // Each element of `cursors` has the same canonical cursor.
    static Cursor[] trueCursorsFromSameCanonical(R)(R cursors) {
        import clang: Cursor;
        import std.algorithm: all, filter;
        import std.array: array;

        // we always accept multiple namespaces
        if(cursors.save.all!(a => a.kind == Cursor.Kind.Namespace))
            return cursors.array;

        auto definitions = cursors.save.filter!(a => a.isDefinition);
        if(!definitions.empty) return [definitions.front];

        auto canonicals = cursors.save.filter!(a => a.isCanonical);
        if(!canonicals.empty) return [canonicals.front];

        assert(!cursors.empty);
        return [cursors.front];
    }

    // Given an arbitrary range of cursors, returns a new range filtering out
    // the "ghosts" (useless repeated cursors).
    static auto trueCursors(R)(R cursors) @trusted {
        import std.algorithm: sort, chunkBy, map;
        import std.array: array, join;

        return cursors
            .array  // needed by sort
            .sort!((a, b) => a.canonical.sourceRange.start <
                             b.canonical.sourceRange.start)
            // each chunk is a range of cursors representing the same canonical entity
            .chunkBy!((a, b) => a.canonical == b.canonical)
            // for each chunk, extract the one cursor we want
            .map!trueCursorsFromSameCanonical
            .join  // flatten (range of chunks of cursors -> range of cursors)
            ;
    }

    auto topLevelCursors = translationUnit.cursor.children;
    auto nsCursors = topLevelCursors.filter!(c => c.kind == Cursor.Kind.Namespace);
    auto nonNsCursors = topLevelCursors.filter!(c => c.kind != Cursor.Kind.Namespace);

    auto trueNsCursors = () @trusted {
        import clang: Cursor;
        import std.algorithm: map, chunkBy;
        import std.typecons: tuple;
        import std.array: array, join;

        return nsCursors
        // each chunk is a range of NS cursors with the same name
        .chunkBy!((a, b) => a.spelling == b.spelling)
        // a range of ("namespace", childrenCursors) tuples
        .map!(nsChunk => tuple(nsChunk.front.spelling, nsChunk.map!(ns => ns.children).join))
        // convert the children to true cursors (filter out ghosts)
        .map!(t => tuple(t[0],  // namespace spelling
                         trueCursors(t[1] /*child cursors*/)))
        // map each tuple to a new Namespace cursor with the "correct" children
        .map!((t) { auto c = Cursor(Cursor.Kind.Namespace, t[0]); c.children = t[1]; return c; })
        .array
        ;
    }();

    auto cursors = trueCursors(nonNsCursors) ~ trueNsCursors;

    // put the macros at the end
    cursors.partition!(a => a.kind != Cursor.Kind.MacroDefinition);

    return cursors;
}


bool isCppHeader(in from!"dpp.runtime.options".Options options, in string headerFileName) @safe pure {
    import std.path: extension;
    if(options.parseAsCpp) return true;
    return headerFileName.extension != ".h";
}


string getHeaderName(in const(char)[] line, in string[] includePaths)
    @safe
{
    const name = getHeaderName(line);
    return name == "" ? name : fullPath(includePaths, name);
}


string getHeaderName(const(char)[] line)
    @safe pure
{
    import std.algorithm: startsWith, countUntil;
    import std.range: dropBack;
    import std.array: popFront;
    import std.string: stripLeft;

    line = line.stripLeft;
    if(!line.startsWith(`#include `)) return "";

    const openingQuote = line.countUntil!(a => a == '"' || a == '<');
    const closingQuote = line[openingQuote + 1 .. $].countUntil!(a => a == '"' || a == '>') + openingQuote + 1;
    return line[openingQuote + 1 .. closingQuote].idup;
}

///
@("getHeaderName")
@safe pure unittest {
    import unit_threaded: shouldEqual;
    getHeaderName(`#include "foo.h"`).shouldEqual(`foo.h`);
    getHeaderName(`#include "bar.h"`).shouldEqual(`bar.h`);
    getHeaderName(`#include "foo.h" // comment`).shouldEqual(`foo.h`);
    getHeaderName(`#include <foo.h>`).shouldEqual(`foo.h`);
    getHeaderName(`    #include "foo.h"`).shouldEqual(`foo.h`);
}



// transforms a header name, e.g. stdio.h
// into a full file path, e.g. /usr/include/stdio.h
private string fullPath(in string[] includePaths, in string headerName) @safe {

    import std.algorithm: map, filter;
    import std.path: buildPath, absolutePath;
    import std.file: exists;
    import std.conv: text;
    import std.exception: enforce;

    if(headerName.exists) return headerName;

    auto filePaths = includePaths
        .map!(a => buildPath(a, headerName).absolutePath)
        .filter!exists;

    enforce(!filePaths.empty, text("d++ cannot find file path for header '", headerName, "'"));

    return filePaths.front;
}
