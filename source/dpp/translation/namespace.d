module dpp.translation.namespace;

import dpp.from;

string[] translateNamespace(in from!"clang".Cursor cursor,
                            ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.Namespace)
    do
{
    import dpp.translation.translation: translate, ignoredCppCursorSpellings;
    import dpp.translation.exception: UntranslatableException;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map, canFind, startsWith, endsWith;
    import std.array: array;

    if(cursor.spelling == "")
        throw new UntranslatableException("BUG: namespace with no name");

    // FIXME - The translated D code isn't valid for a lot of these
    // boost namespaces
    enum problematicNamespaces = [
        "boost",
        "mpl",
        "mpl_",
        "container",
        "range",
        "iterators",
        "placeholders",
        "rel_ops",
    ];
    if(problematicNamespaces.canFind(cursor.spelling) || cursor.spelling.endsWith("detail"))
        throw new UntranslatableException("Currently unsupported namespace");


    string[] lines;

    lines ~= [
            `extern(C++, "` ~ cursor.spelling ~ `")`,
            `{`,
    ];

    foreach(child; cursor.children) {

        if(child.kind == Cursor.Kind.VisibilityAttr) continue;

        lines ~= translate(child, context)
            .map!(a => (child.kind == Cursor.Kind.Namespace ? "    " : "        ") ~ a)
            .array;
    }

    lines ~= `}`;

    return lines;
}
