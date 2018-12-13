/**
   Deals with expanding #include directives inline.
 */
module dpp2.expansion;


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
    import dpp.runtime.context: Language;
    import dpp2.translation.node: translate;
    import clang: parse;

    const extern_ = context.language == Language.Cpp ? "extern(C++)" : "extern(C)";
    context.writeln([extern_, "{"]);

    const translationUnit = parseTU(translUnitFileName, context);
    const topLevelCursors = translationUnit.cursor.children;
    auto nodes = cursorsToNodes(topLevelCursors);

    foreach(node; nodes) {
        const indentation = context.indentation;
        const lines = translate(node);
        if(lines.length) context.writeln(lines);
        context.setIndentation(indentation);
    }

    context.writeln(["}", ""]);
    context.writeln("");
}


// returns a range of dpp2.sea.Node
private auto cursorsToNodes(in from!"clang".Cursor[] cursors) @safe {
    import dpp2.transform: toNode;
    import clang: Cursor;
    import std.algorithm: map, filter;
    import std.array: join;

    auto nested = cursors
        .filter!(c => c.kind != Cursor.Kind.MacroDefinition && c.kind != Cursor.Kind.InclusionDirective)
        .map!toNode
        ;
    return () @trusted { return nested.join; }();
}

private from!"clang".TranslationUnit parseTU(
        in string translUnitFileName,
        ref from!"dpp.runtime.context".Context context,
    )
    @safe
{
    import clang: parse, TranslationUnitFlags;
    const args = clangArgs(context, translUnitFileName);
    return parse(translUnitFileName,
                 args,
                 TranslationUnitFlags.DetailedPreprocessingRecord);
}

string[] clangArgs(in from!"dpp.runtime.context".Context context,
                   in string inputFileName)
    @safe pure
{
    import dpp.runtime.context: Language;
    import std.algorithm: map;
    import std.range: chain;
    import std.array: array;

    auto args =
        chain(
            includePaths(context.options, inputFileName).map!(a => "-I" ~ a),
            context.options.defines.map!(a => "-D" ~ a)
        ).array;

    if(context.options.parseAsCpp || context.language == Language.Cpp)
        args ~= ["-xc++", "-std=c++14"];
    else
        args ~= "-xc";

    return args;
}


string[] includePaths(in from!"dpp.runtime.options".Options options,
                      in string inputFileName)
    @safe pure
{
    import std.path: dirName;
    return options.includePaths.dup ~ inputFileName.dirName;
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
