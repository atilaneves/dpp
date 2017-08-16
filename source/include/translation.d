/**
   This module expands each header encountered in the original input file.
   It usually delegates to dstep but not always. Since dstep has a different
   goal, which is to produce human-readable D files from a header, we can't
   just call into it.

   The translate function here will handle the cases it knows how to deal with,
   otherwise it asks dstep to it for us.
 */

module include.translation;


import clang.TranslationUnit: TranslationUnit;
import clang.Cursor: Cursor;

version(unittest) {
    import unit_threaded;
    import include.test_util;
}


/**
   If an #include directive, expand in place,
   otherwise do nothing (i.e. return the same line)
 */
string maybeExpand(in const(char)[] line, ref string[] macros) @safe {

    const headerName = getHeaderName(line);

    return headerName == ""
        ? line.idup
        : expand(headerName.toFileName, macros);
}


@("translate no include")
@safe unittest {
    string[] macros;
    "foo".maybeExpand(macros).shouldEqual("foo");
    "bar".maybeExpand(macros).shouldEqual("bar");
    macros.shouldBeEmpty;
}


private string expand(in string headerFileName, ref string[] macros) @safe {
    import include.clang: parse;

    string ret;

    ret ~= "extern(C) {\n";

    auto translationUnit = parse(headerFileName);
    auto dstep = DStep(translationUnit);

    () @trusted {
        foreach(cursor, parent; translationUnit.cursor.allInOrder) {
            ret ~= translate(macros, dstep, translationUnit, cursor, parent);
        }
    }();

    ret ~= "}\n";

    return ret;
}


private struct DStep {

    import clang.TranslationUnit: TranslationUnit;
    import clang.Cursor: Cursor;
    import dstep.translator.Translator: Translator;
    import std.typecons: Yes;

    TranslationUnit translationUnit;
    Translator translator;

    this(TranslationUnit translationUnit) @safe {
        import dstep.translator.Options: Options;

        this.translationUnit = translationUnit;
        Options options;
        options.enableComments = false;
        options.allTypedefs = Yes.allTypedefs;

        translator = () @trusted { return new Translator(translationUnit, options); }();
    }

    string translate(ref Cursor cursor, ref Cursor parent) @trusted {
        import dstep.translator.Output: Output;

        static bool[string] alreadyTranslated;

        Output output = new Output(translator.context.commentIndex);

        translator.translateInGlobalScope(output, cursor, parent);
        if (translator.context.commentIndex)
            output.flushLocation(translator.context.commentIndex.queryLastLocation());

        // foreach (value; translator.deferredDeclarations.values)
        //     output.singleLine(value);

        output.finalize();

        auto ret =  output.content;

        if(ret in alreadyTranslated) return "";

        alreadyTranslated[ret] = true;

        return ret;
    }
}

private string translate(ref string[] macros,
                         ref DStep dstep,
                         ref TranslationUnit translationUnit,
                         ref Cursor cursor,
                         ref Cursor parent)
    @trusted
{
    if(skipCursor(cursor)) return "";

    auto translation = translateOurselves(macros, cursor);

    if(translation.ignore) return "";
    if(translation.dstep) return dstep.translate(cursor, parent);

    return translation.value;
}


private struct Translation {

    enum State {
        ignore,
        dstep,
        valid,
    }

    bool ignore() @safe @nogc pure nothrow const {
        return state == State.ignore;
    }

    bool dstep() @safe @nogc pure nothrow const {
        return state == State.dstep;
    }

    bool valid() @safe @nogc pure nothrow const {
        return state == State.valid;
    }

    string value;
    State state;

    this(string value) @safe pure {
        this.value = value;
        this.state = State.valid;
    }

    this(State state) @safe pure {
        assert(state != State.valid);
        this.state = state;
    }
}

private Translation translateOurselves(ref string[] macros, ref Cursor cursor) {
    static bool[string] alreadyTranslated;

    const translated = translateImpl(macros, cursor);

    if(translated.valid && translated.value in alreadyTranslated)
        return Translation(Translation.State.ignore);

    alreadyTranslated[translated.value] = true;
    return translated;
}

private Translation translateImpl(ref string[] macros, ref Cursor cursor) {
    import clang.c.Index: CXCursorKind;
    import std.format: format;
    import std.algorithm: map;
    import std.string: join;
    import std.file: exists;
    import std.stdio: File;
    import std.algorithm: startsWith;

    static bool[string] alreadyDefined;

    switch(cursor.kind) with(CXCursorKind) {

        default:
            return Translation(Translation.State.dstep);

        case CXCursor_MacroDefinition:

            // we want non-built-in macro definitions to be defined and then preprocessed
            // again

            auto range = cursor.extent;

            if(range.path == "" || !range.path.exists || cursor.isPredefined) { //built-in macro
                return Translation(Translation.State.ignore);
            }

            // now we read the header where the macro comes from and copy the text inline

            const startPos = range.start.offset;
            const endPos   = range.end.offset;

            auto file = File(range.path);
            file.seek(startPos);
            const chars = file.rawRead(new char[endPos - startPos]);

            // the only sane way for us to be able to see a macro definition
            // for a macro that has already been defined is if an #undef happened
            // in the meanwhile. Unfortunately, libclang has no way of passing
            // that information to us
            string maybeUndef;
            if(cursor.spelling in alreadyDefined)
                maybeUndef = "#undef " ~ cursor.spelling ~ "\n";

             alreadyDefined[cursor.spelling] = true;

             macros ~= maybeUndef ~ "#define %s\n".format(chars);

             return Translation(Translation.State.ignore);
    }
}

private bool skipCursor(ref Cursor cursor) {
    import std.algorithm: startsWith, canFind;

    static immutable forbiddenSpellings =
        [
            "ulong", "ushort", "uint",
        ];

    if(forbiddenSpellings.canFind(cursor.spelling)) return true;
    if(cursor.isPredefined) return true;

    return false;
}


private string getHeaderName(const(char)[] line) @safe pure {
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
