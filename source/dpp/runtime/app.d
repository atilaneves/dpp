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

    import dpp.runtime.context: Context;
    import dpp.expansion: maybeExpand;
    import std.algorithm: map, startsWith, filter;
    import std.process: execute;
    import std.exception: enforce;
    import std.conv: text;
    import std.string: splitLines;
    import std.file: remove;
    import std.array: replace;

    const tmpFileName = outputFileName ~ ".tmp";
    scope(exit) if(!options.keepPreCppFile) remove(tmpFileName);

    {
        auto outputFile = File(tmpFileName, "w");

        outputFile.writeln(preamble);

        /**
           We remember the cursors already seen so as to not try and define
           something twice (legal in C, illegal in D).
        */
        auto context = Context(options.indent);

        () @trusted {
            foreach(immutable line; File(inputFileName).byLine.map!(a => cast(string)a)) {
                // If the line is an #include directive, expand its translations "inline"
                // into the context structure.
                line.maybeExpand(context);
            }
        }();

        context.fixNames;
        outputFile.writeln(context.translation);
    }

    const ret = execute(["cpp", tmpFileName]);
    enforce(ret.status == 0, text("Could not run cpp on ", tmpFileName, ":\n", ret.output));

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
        struct __locale_data { int dummy; }  // FIXME
        #define __gnuc_va_list va_list
        alias _Bool = bool;

        struct dpp {

            static struct Move(T) {
                T value;
            }

            // FIXME - crashes if T is passed by value (which we want)
            static auto move(T)(ref T value) {
                return Move!T(value);
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
