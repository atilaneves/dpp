/**
   Deals with expanding #include directives inline.
 */
module dpp.expansion;


import dpp.from;


enum Language {
    C,
    Cpp,
}

/**
   Params:
       translUnitFileName = The file name with all #include directives to parse
       context = The translation context
       language = Whether it's a C or C++ file
       includePaths = The list of files to pass as -I options to clang
 */
void expand(in string translUnitFileName,
            ref from!"dpp.runtime.context".Context context,
            in Language language,
            in string[] includePaths,
            in string file = __FILE__,
            in size_t line = __LINE__)
    @safe
{
    import dpp.translation.translation: translateTopLevelCursor;
    import clang: Cursor;

    const extern_ = language == Language.Cpp ? "extern(C++)" : "extern(C)";
    context.writeln([extern_, "{"]);

    auto translationUnit = parseTU(translUnitFileName, context, language, includePaths);
    auto cursors = canonicalCursors(translationUnit);

    foreach(cursor; cursors) {

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
        in Language language,
        in string[] includePaths,
    )
    @safe
{
    import clang: parse, TranslationUnitFlags;
    import std.array: array;
    import std.algorithm: map;

    auto parseArgs =
        includePaths.map!(a => "-I" ~ a).array ~
        context.options.defines.map!(a => "-D" ~ a).array
        ;

    if(context.options.parseAsCpp || language == Language.Cpp)
        parseArgs ~= "-xc++";
    else
        parseArgs ~= "-xc";

    return parse(translUnitFileName,
                 parseArgs,
                 TranslationUnitFlags.DetailedPreprocessingRecord);
}

// returns a range of Cursor
private auto canonicalCursors(from!"clang".TranslationUnit translationUnit) @safe {

    import dpp.translation.translation: translateTopLevelCursor;
    import clang: Cursor;
    import std.array: array, join;
    import std.algorithm: sort, filter, map, chunkBy, all;

    // In C there can be several declarations and one definition of a type.
    // In D we can have only ever one of either. There might be multiple
    // cursors in the translation unit that all refer to the same canonical type.
    // Unfortunately, the canonical type is orthogonal to which cursor is the actual
    // definition, so we prefer to find the definition if it exists, and if not, we
    // take the canonical declaration so as to not repeat ourselves in D.
    static Cursor[] trueCursors(R)(R cursors) {

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

    static bool goodCursor(in Cursor cursor) {
        return cursor.isCanonical || cursor.isDefinition;
    }

    return () @trusted {
        return translationUnit
        .cursor
        .children
        // sort them by canonical cursor
        .sort!((a, b) => a.canonical.sourceRange.start <
                         b.canonical.sourceRange.start)
        // each chunk is a range of cursors representing the same canonical entity
        .chunkBy!((a, b) => a.canonical == b.canonical)
        // for each chunk, extract the one cursor we want
        .map!trueCursors
        .join  // flatten
        // libclang gives us macros first, so we sort by line here
        // (we also just messed up the order above as well)
        .sort!((a, b) => a.sourceRange.start.line < b.sourceRange.start.line)
        ;
    }();
}

bool isCppHeader(in string headerFileName) @safe pure {
    import std.path: extension;
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
