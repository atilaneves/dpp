module dpp.translation.namespace;


import dpp.from;


string[] translateNamespace(in from!"clang".Cursor cursor,
                            ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.Namespace)
    do
{
    import dpp.translation.translation: translate;
    import dpp.translation.exception: UntranslatableException;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map, startsWith;
    import std.array: array;

    if(shouldSkip(cursor.spelling, context))
        return [];

    if(cursor.spelling == "")
        throw new UntranslatableException("BUG: namespace with no name");

    string[] lines;

    lines ~= [
            `extern(C++, "` ~ cursor.spelling ~ `")`,
            `{`,
    ];

    context.pushNamespace(cursor.spelling);
    scope(exit) context.popNamespace(cursor.spelling);

    foreach(child; cursor.children) {

        if(child.kind == Cursor.Kind.VisibilityAttr) continue;
        if(cursor.spelling == "std" && child.spelling.startsWith("__")) continue;

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
