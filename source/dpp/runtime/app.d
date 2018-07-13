/**
   Code to make the executable do what it does at runtime.
 */
module dpp.runtime.app;

import dpp.from;

/**
   The "real" main
 */
void run(in from!"dpp.runtime.options".Options options) @safe {
    import std.stdio: File;
    import std.exception: enforce;
    import std.process: execute;
    import std.array: join;
    import std.file: remove;

    foreach(dppFileName; options.dppFileNames)
        preprocess!File(options, dppFileName, options.toDFileName(dppFileName));

    if(options.preprocessOnly) return;

    const args = options.dlangCompiler ~ options.dlangCompilerArgs;
    const res = execute(args);
    enforce(res.status == 0, "Could not execute `" ~ args.join(" ") ~ "`:\n" ~ res.output);

    if(!options.keepDlangFiles) {
        foreach(fileName; options.dFileNames)
            remove(fileName);
    }
}

/**
   Preprocesses a quasi-D file, expanding #include directives inline while
   translating all definitions, and redefines any macros defined therein.

   The output is a valid D file that can be compiled.

   Params:
        options = The runtime options.
 */
void preprocess(File)(in from!"dpp.runtime.options".Options options,
                      in string inputFileName,
                      in string outputFileName)
{
    import std.file: remove;

    const tmpFileName = outputFileName ~ ".tmp";
    scope(exit) if(!options.keepPreCppFiles) remove(tmpFileName);

    {
        auto outputFile = File(tmpFileName, "w");

        // write preamble code
        outputFile.writeln(preamble);

        // write translated D definitions
        outputFile.writeln(translationText!File(options, inputFileName));

        // write original D code
        writeDlangLines(inputFileName, outputFile);
    }

    runCPreProcessor(tmpFileName, outputFileName);
}

// the translated D code from all #included files
private string translationText(File)(in from!"dpp.runtime.options".Options options,
                                     in string inputFileName)
{

    import dpp.runtime.context: Context;
    import dpp.expansion: expand, isCppHeader, getHeaderName, Language;
    import std.algorithm: map, filter;
    import std.string: fromStringz;
    import std.path: dirName;
    import core.stdc.stdio: tmpnam;

    /**
       We remember the cursors already seen so as to not try and define
       something twice (legal in C, illegal in D).
    */
    auto context = Context(options.indent);

    () @trusted {

        auto inputFile = File(inputFileName);
        auto lines = inputFile.byLine.map!(a => cast(string) a);
        const includePaths = context.options.includePaths ~ inputFileName.dirName;
        auto includes = lines.map!(a => getHeaderName(a, includePaths)).filter!(a => a != "");
        char[1024] tmpnamBuf;
        const includesFileName = cast(string) tmpnam(&tmpnamBuf[0]).fromStringz;
        auto language = Language.C;
        // write a temporary file with all #included files in it
        {
            auto includesFile = File(includesFileName, "w");
            foreach(include; includes) {
                includesFile.writeln(`#include "`, include, `"`);
                if(isCppHeader(include)) language = Language.Cpp;
            }
        }

        // parse all #includes at once and populate context with
        // D definitions
        expand(includesFileName, context, language, includePaths);
    }();

    context.fixNames;

    return context.translation;
}

// write the original D code that doesn't need translating
private void writeDlangLines(in string inputFileName, ref from!"std.stdio".File outputFile) @trusted {

    import dpp.expansion: getHeaderName;
    import std.stdio: File;
    import std.algorithm: map;

    foreach(immutable line; File(inputFileName).byLine.map!(a => cast(string)a)) {
        if(getHeaderName(line) == "")
            // not an #include directive, just pass through
            outputFile.writeln(line);
        // otherwise do nothing
    }

}

private void runCPreProcessor(in string tmpFileName, in string outputFileName) @safe {

    import std.exception: enforce;
    import std.process: execute;
    import std.conv: text;
    import std.string: join, splitLines;
    import std.stdio: File;
    import std.algorithm: filter, startsWith;

    const cppArgs = ["cpp", tmpFileName];
    const ret = execute(cppArgs);
    enforce(ret.status == 0, text("Could not run `", cppArgs.join(" "), "`:\n", ret.output));

    {
        auto outputFile = File(outputFileName, "w");
        auto lines = ret.
            output
            .splitLines
            .filter!(a => !a.startsWith("#"))
            ;

        foreach(line; lines) {
            outputFile.writeln(line);
        }
    }

}


private string preamble() @safe pure {
    import std.array: replace, join;
    import std.algorithm: map, filter;
    import std.string: splitLines;

    return q{

        import core.stdc.config;
        import core.stdc.stdarg: va_list;
        static import core.simd;

        struct __locale_data { int dummy; }  // FIXME
    } ~
        `    #define __gnuc_va_list va_list` ~ "\n" ~

          q{
        alias _Bool = bool;

        struct dpp {

            static struct Move(T) {
                T* ptr;
            }

            // FIXME - crashes if T is passed by value (which we want)
            static auto move(T)(ref T value) {
                return Move!T(&value);
            }


            mixin template EnumD(string name, T, string prefix) if(is(T == enum)) {

                private static string _memberMixinStr(string member) {
                    import std.conv: text;
                    import std.array: replace;
                    return text(`    `, member.replace(prefix, ""), ` = `, T.stringof, `.`, member, `,`);
                }

                private static string _enumMixinStr() {
                    import std.array: join;

                    string[] ret;

                    ret ~= "enum " ~ name ~ "{";

                    static foreach(member; __traits(allMembers, T)) {
                        ret ~= _memberMixinStr(member);
                    }

                    ret ~= "}";

                    return ret.join("\n");
                }

                mixin(_enumMixinStr());
            }
        }
    }
    .splitLines
    .filter!(a => a != "")
    .map!(a => a.length >= 8 ? a[8 .. $] : a) // get rid of leading spaces
    .join("\n");
}
