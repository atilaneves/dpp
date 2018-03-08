/**
   This module expands each header encountered in the original input file.
   It usually delegates to dstep but not always. Since dstep has a different
   goal, which is to produce human-readable D files from a header, we can't
   just call into it.

   The translate function here will handle the cases it knows how to deal with,
   otherwise it asks dstep to it for us.
 */

module include.translation;


import clang: TranslationUnit, Cursor, Type;

version(unittest) {
    import unit_threaded;
    import include.test_util;
}


/**
   If an #include directive, expand in place,
   otherwise do nothing (i.e. return the same line)
 */
string maybeExpand(string line) @safe {

    const headerName = getHeaderName(line);

    return headerName == ""
        ? line
        : expand(headerName.toFileName);
}


@("translate no include")
@safe unittest {
    "foo".maybeExpand.shouldEqual("foo");
    "bar".maybeExpand.shouldEqual("bar");
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
private string toFileName(in string headerName) @safe {

    import std.algorithm: map, filter;
    import std.path: buildPath, absolutePath;
    import std.file: exists;
    import std.conv: text;
    import std.exception: enforce;

    if(headerName.exists) return headerName;

    const dirs = ["/usr/include"];
    auto filePaths = dirs.map!(a => buildPath(a, headerName).absolutePath).filter!exists;
    enforce(!filePaths.empty, text("Cannot find file path for header '", headerName, "'"));
    return filePaths.front;
}


string expand(in string headerFileName) @safe {
    import clang: parse, TranslationUnitFlags;
    import std.array: join;

    string[] ret;

    ret ~= "extern(C) {";

    auto translationUnit = parse(headerFileName,
                                 TranslationUnitFlags.DetailedPreprocessingRecord);

    foreach(cursor, parent; translationUnit) {
        ret ~= translate(translationUnit, cursor, parent);
    }

    ret ~= "}";
    ret ~= "";

    return ret.join("\n");
}


private string translate(ref TranslationUnit translationUnit,
                         ref Cursor cursor,
                         ref Cursor parent)
    @safe
{
    import std.array: join;

    if(skipCursor(cursor)) return "";

    return translate(cursor).join("\n");
}

private bool skipCursor(ref Cursor cursor) @safe pure {
    import std.algorithm: startsWith, canFind;

    static immutable forbiddenSpellings =
        [
            "ulong", "ushort", "uint",
            "va_list", "__gnuc_va_list",
            "_IO_2_1_stdin_", "_IO_2_1_stdout_", "_IO_2_1_stderr_",
        ];

    return forbiddenSpellings.canFind(cursor.spelling) || cursor.isPredefined;
}


string[] translate(Cursor cursor) @safe {

    import std.conv: text;
    import std.array: join;

    switch(cursor.kind) with(Cursor.Kind) {
        default:
            return [];

        case StructDecl:
            string[] ret;

            ret ~= `struct Foo {`;
            foreach(field; cursor) {
                ret ~= translateField(field);
            }
            ret ~= `}`;

            return ret;

        case FunctionDecl:
            const returnType = "Foo";
            const name = "addFoos";
            const types = ["Foo*", "Foo*"];
            return [text(returnType, " ", name, "(", types.join(", "), ");")];
    }
}

string translate(in Type type) @safe pure {

    import std.conv: text;

    switch(type.kind) with(Type.Kind) {

        default:
            assert(false, text("Type kind ", type.kind, " not supported"));

        case Int:
            return "int";

        case Double:
            return "double";
    }
}


string translateField(in Cursor field) @safe pure {
    import std.conv: text;

    assert(field.kind == Cursor.Kind.FieldDecl);
    const type = translate(field.type);
    const name = field.spelling;
    return text(type, " ", name, ";");
}
