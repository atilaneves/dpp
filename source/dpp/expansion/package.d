/**
   Deals with expanding #include directives inline.
 */
module dpp.expansion;


import dpp.from;
// default implementation
public import dpp.expansion.libclang;



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
    import dpp.translation.translation: translateTopLevel;
    import dpp.runtime.context: Language;
    import dpp.ast.node: Node;

    const extern_ = () {
        final switch(context.language) {
            case Language.Cpp:
                return "extern(C++)";
            case Language.C:
                return "extern(C)";
        }
    }();

    context.writeln([extern_, "{"]);

    auto nodes = tuToNodes(translUnitFileName, context, includePaths);

    foreach(node; nodes) {

        if(context.hasSeen(node)) continue;
        context.rememberNode(node);

        const indentation = context.indentation;
        const lines = translateTopLevel(node, context, file, line);
        if(lines.length) context.writeln(lines);
        context.setIndentation(indentation);
    }

    context.writeln(["}", ""]);
    context.writeln("");
}
