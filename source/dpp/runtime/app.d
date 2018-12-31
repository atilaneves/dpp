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

    // See #102. We need some C++ boilerplate to link to the application.
    scope(exit) if(options.cppStdLib) remove(CppBoilerplateCode.objFileName);
    if(options.cppStdLib) CppBoilerplateCode.generate;
    const cppExtraArgs = options.cppStdLib ? [CppBoilerplateCode.objFileName] : [];

    const args = options.dlangCompiler ~ options.dlangCompilerArgs ~ cppExtraArgs;
    const res = execute(args);
    enforce(res.status == 0, "Could not execute `" ~ args.join(" ") ~ "`:\n" ~ res.output);

    if(!options.keepDlangFiles) {
        foreach(fileName; options.dFileNames)
            remove(fileName);
    }
}


// See #102. We need some C++ boilerplate to link to the application.
private struct CppBoilerplateCode {

    enum baseFileName = "cpp_boilerplate";
    enum srcFileName = baseFileName ~ ".cpp";
    version(Windows)
        enum objFileName = baseFileName ~ ".obj";
    else
        enum objFileName = baseFileName ~ ".o";


    static void generate() @safe {

        import std.stdio: File;
        import std.file: remove;

        writeSrcFile;
        scope(exit) remove(srcFileName);
        compileSrcFile;
    }

    ~this() @safe {
        import std.file: remove;
        remove(objFileName);
    }

    static void writeSrcFile() @safe {
        import std.stdio: File;

        auto file = File(srcFileName, "w");
        file.writeln(`#include <vector>`);
        file.writeln(`void cpp_stdlib_boilerplate_dpp() {`);
        file.writeln(`    std::vector<bool> v;`);
        file.writeln(`    (void) (v[0] == v[0]);`);
        file.writeln(`    (void) (v.begin() == v.begin());`);
        file.writeln(`}`);
    }

    static void compileSrcFile() @safe {
        import std.process: execute;
        import std.file: exists;

        const args = ["-c", srcFileName];
        const gccArgs = "g++" ~ args;
        const clangArgs = "clang++" ~ args;

        scope(success) assert(exists(objFileName), objFileName ~ " was expected to exist but did not");

        const gccRet = execute(gccArgs);
        if(gccRet.status == 0) return;

        const clangRet = execute(clangArgs);
        if(clangRet.status != 0)
            throw new Exception("Could not compile C++ boilerplate with either gcc or clang");
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

        const translationText = translationText!File(options, inputFileName);

        outputFile.writeln(translationText.moduleDeclaration);
        outputFile.writeln(preamble);
        outputFile.writeln(translationText.dlangDeclarations);

        // write original D code
        writeDlangLines(inputFileName, outputFile);
    }

    runCPreProcessor(tmpFileName, outputFileName);
}

private struct TranslationText {
    string moduleDeclaration;
    string dlangDeclarations;
}

// the translated D code from all #included files
private TranslationText translationText(File)(in from!"dpp.runtime.options".Options options,
                                              in string inputFileName)
{

    import dpp.runtime.context: Context, Language;
    version(dpp2)
        import dpp2.expansion: expand, isCppHeader, getHeaderName;
    else
        import dpp.expansion: expand, isCppHeader, getHeaderName;

    import std.algorithm: map, filter;
    import std.string: fromStringz;
    import std.path: dirName;
    import std.array: array, join;
    import core.stdc.stdio: tmpnam;

    auto inputFile = File(inputFileName);
    const lines = () @trusted { return inputFile.byLine.map!(a => a.idup).array; }();
    auto moduleLines = () @trusted { return lines.filter!isModuleLine.array; }();
    auto nonModuleLines = lines.filter!(a => !isModuleLine(a));
    const includePaths = options.includePaths ~ inputFileName.dirName;
    auto includes = nonModuleLines.map!(a => getHeaderName(a, includePaths)).filter!(a => a != "");
    char[1024] tmpnamBuf;
    const includesFileName = () @trusted { return cast(string) tmpnam(&tmpnamBuf[0]).fromStringz; }();
    auto language = Language.C;
    // write a temporary file with all #included files in it
    () @trusted {
        auto includesFile = File(includesFileName, "w");
        foreach(include; includes) {
            includesFile.writeln(`#include "`, include, `"`);
            if(isCppHeader(options, include)) language = Language.Cpp;
        }
    }();

    /**
       We remember the cursors already seen so as to not try and define
       something twice (legal in C, illegal in D).
    */
    auto context = Context(options.indent, language,options.typeRemappingsFile,options.headerBlacklistFile);

    // parse all #includes at once and populate context with
    // D definitions
    expand(includesFileName, context, includePaths);

    context.fixNames;

    return TranslationText(moduleLines.join("\n"), context.translation);
}

// write the original D code that doesn't need translating
private void writeDlangLines(in string inputFileName, ref from!"std.stdio".File outputFile)
    @trusted
{

    import dpp.expansion: getHeaderName;
    import std.stdio: File;
    import std.algorithm: filter;

    foreach(line; File(inputFileName).byLine.filter!(a => !isModuleLine(a))) {
        if(getHeaderName(line) == "")
            // not an #include directive, just pass through
            outputFile.writeln(line);
        // otherwise do nothing
    }
}

bool isModuleLine(in const(char)[] line) @safe pure {
    import std.string: stripLeft;
    import std.algorithm: startsWith;
    return line.stripLeft.startsWith("module ");
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


string preamble() @safe pure {
    import std.array: replace, join;
    import std.algorithm: map, filter;
    import std.string: splitLines;

    return q{

        import core.stdc.config;
        import core.stdc.stdarg: va_list;
        static import core.simd;
        static import std.conv;
	struct Opaque(string TypeName,size_t BlobSize)
	{
		import std.exception:enforce;
		ubyte[BlobSize] blob;
		alias blob this;
		enum blobSize = BlobSize;
		enum typeName = TypeName;

		this(ubyte[] blob)
		{
			enforce(blob.length == BlobSize);
			this.blob=blob;
		}
	}

        struct Int128 { long lower; long upper; }
        struct UInt128 { ulong lower; ulong upper; }

        struct __locale_data { int dummy; }  // FIXME
    } ~
          "    #define __gnuc_va_list va_list\n" ~
          "    #define __is_empty(_Type) dpp.isEmpty!(_Type)\n" ~

          q{
        alias _Bool = bool;

        struct dpp {

            // Replacement for the gcc/clang intrinsic
            static bool isEmpty(T)() {
                return T.tupleof.length == 0;
            }

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
