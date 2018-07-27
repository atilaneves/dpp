/**
   Deals with expanding #include directives inline.
 */
module dpp.expansion;

import dpp.from;

enum Language {
    C,
    Cpp,
}

void expand(in string translUnitFileName,
            ref from!"dpp.runtime.context".Context context,
            in Language language,
            in string[] includePaths,
            in string file = __FILE__,
            in size_t line = __LINE__)
    @safe
{
    import dpp.translation.translation: translateTopLevelCursor;
    import clang: parse, TranslationUnitFlags, Cursor;
    import std.array: join, array;
    import std.algorithm: sort, filter, map, chunkBy, any;

    auto parseArgs =
        includePaths.map!(a => "-I" ~ a).array ~
        context.options.defines.map!(a => "-D" ~ a).array
        ;

    if(context.options.parseAsCpp || language == Language.Cpp)
        parseArgs ~= "-xc++";
    else
        parseArgs ~= "-xc";

    auto translationUnit = parse(translUnitFileName,
                                 parseArgs,
                                 TranslationUnitFlags.DetailedPreprocessingRecord);

    // In C there can be several declarations and one definition of a type.
    // In D we can have only ever one of either. There might be multiple
    // cursors in the translation unit that all refer to the same canonical type.
    // Unfortunately, the canonical type is orthogonal to which cursor is the actual
    // definition, so we prefer to find the definition if it exists, and if not, we
    // take the canonical declaration so as to not repeat ourselves in D.
    static Cursor trueCursor(R)(R cursors) {

        if(cursors.save.any!(a => a.isDefinition))
            return cursors.filter!(a => a.isDefinition).front;

        if(cursors.save.any!(a => a.isCanonical))
            return cursors.filter!(a => a.isCanonical).front;

        assert(!cursors.empty);
        return cursors.front;
    }

    static bool goodCursor(in Cursor cursor) {
        return cursor.isCanonical || cursor.isDefinition;
    }

    auto cursors = () @trusted {
        return translationUnit
        .cursor
        .children
        // sort them by canonical cursor
        .sort!((a, b) => a.canonical.sourceRange.start <
                         b.canonical.sourceRange.start)
        // each chunk is a range of cursors representing the same canonical entity
        .chunkBy!((a, b) => a.canonical == b.canonical)
        // for each chunk, extract the one cursor we want
        .map!trueCursor
        // array is needed for sort
        .array
        // libclang gives us macros first, so we sort by line here
        // (we also just messed up the order above as well)
        .sort!((a, b) => a.sourceRange.start.line < b.sourceRange.start.line)
        ;
    }();

    //const extern_ = isCppHeader(translUnitFileName) ? "extern(C++)" : "extern(C)";
    const extern_ = language == Language.Cpp ? "extern(C++)" : "extern(C)";
    context.writeln([extern_, "{"]);

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

bool isCppHeader(in string headerFileName) @safe pure {
    import std.path: extension;
    return headerFileName.extension != ".h";
}


string getHeaderName(in string line, in string[] includePaths)
    @safe
{
    const name = getHeaderName(line);
    return name == "" ? name : fullPath(includePaths, name);
}


string getHeaderName(string line)
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
    return line[openingQuote + 1 .. closingQuote];
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
