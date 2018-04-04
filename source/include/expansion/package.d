/**
   Deals with expanding 3include directives inline.
 */
module include.expansion;

import include.from;

version(unittest) {
    import unit_threaded: shouldEqual;
}


/**
   If an #include directive, expand in place,
   otherwise do nothing (i.e. return the same line)
 */
string maybeExpand(string line,
                   ref from!"include.runtime.context".Context context)
    @safe
{
    const headerName = getHeaderName(line);

    return headerName == ""
        ? line
        : expand(toFileName(context.options.includePaths, headerName),
                 context);
}


@("translate no include")
@safe unittest {
    import include.runtime.context: Context;
    Context context;
    maybeExpand("foo", context).shouldEqual("foo");
    maybeExpand("bar", context).shouldEqual("bar");
}

private string getHeaderName(string line) @safe pure {
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

@("getHeaderFileName")
@safe pure unittest {
    getHeaderName(`#include "foo.h"`).shouldEqual(`foo.h`);
    getHeaderName(`#include "bar.h"`).shouldEqual(`bar.h`);
    getHeaderName(`#include "foo.h" // comment`).shouldEqual(`foo.h`);
    getHeaderName(`#include <foo.h>`).shouldEqual(`foo.h`);
    getHeaderName(`    #include "foo.h"`).shouldEqual(`foo.h`);
}

// transforms a header name, e.g. stdio.h
// into a full file path, e.g. /usr/include/stdio.h
private string toFileName(in string[] includePaths, in string headerName) @safe {

    import std.algorithm: map, filter;
    import std.path: buildPath, absolutePath;
    import std.file: exists;
    import std.conv: text;
    import std.exception: enforce;

    if(headerName.exists) return headerName;

    auto filePaths = includePaths
        .map!(a => buildPath(a, headerName).absolutePath)
        .filter!exists;

    enforce(!filePaths.empty, text("Cannot find file path for header '", headerName, "'"));

    return filePaths.front;
}


string expand(in string headerFileName,
              ref from!"include.runtime.context".Context context,
              in string file = __FILE__,
              in size_t line = __LINE__)
    @safe
{
    import include.cursor.unit: translate;
    import clang: parse, TranslationUnitFlags, Cursor;
    import std.array: join, array;
    import std.algorithm: sort, filter, map, chunkBy, any;

    auto translationUnit = parse(headerFileName,
                                 context.options.includePaths.map!(a => "-I" ~ a).array,
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

    string[] ret;

    ret ~= isCppHeader(headerFileName) ? "extern(C++)" : "extern(C)";
    ret ~= "{";

    foreach(cursor; cursors) {

        if(context.hasSeen(cursor)) continue;
        context.remember(cursor);

        const indentation = context.indentation;
        const lines = translate(context, cursor, file, line);
        if(lines.length) ret ~= lines;
        context.setIndentation(indentation);
    }

    ret ~= "}";
    ret ~= "";

    return ret.join("\n");
}

private bool isCppHeader(in string headerFileName) @safe pure {
    import std.path: extension;
    return headerFileName.extension != ".h";
}
