module dpp.translation.namespace;


import dpp.from;


string[] translateNamespace(in from!"dpp.ast.node".Node node,
                            ref from!"dpp.runtime.context".Context context)
    @safe
    in(node.kind == from!"clang".Cursor.Kind.Namespace)
    do
{
    import dpp.translation.translation: translate, ignoredCppCursorSpellings;
    import dpp.translation.exception: UntranslatableException;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map, startsWith;
    import std.array: array;

    if(shouldSkip(node.spelling, context))
        return [];

    if(node.spelling == "")
        throw new UntranslatableException("BUG: namespace with no name");

    string[] lines;

    lines ~= [
            `extern(C++, "` ~ node.spelling ~ `")`,
            `{`,
    ];

    context.pushNamespace(node.spelling);
    scope(exit) context.popNamespace(node.spelling);

    foreach(child; node.children) {

        if(child.kind == Cursor.Kind.VisibilityAttr) continue;

        lines ~= translate(child, context)
            .map!(a => (child.kind == Cursor.Kind.Namespace ? "    " : "        ") ~ a)
            .array;
    }

    lines ~= `}`;

    return lines;
}


private bool shouldSkip(in string spelling, in from!"dpp.runtime.context".Context context)
    @safe pure
{
    import std.algorithm: canFind;
    return context.options.ignoredNamespaces.canFind(spelling);
}
