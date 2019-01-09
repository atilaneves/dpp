module dpp.translation.namespace;

import dpp.from;

string[] translateNamespace(in from!"clang".Cursor cursor,
                            ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.Namespace)
    do
{
    import dpp.expansion: trueCursors;
    import dpp.translation.translation: translate, ignoredCppCursorSpellings;
    import dpp.translation.exception: UntranslatableException;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map, startsWith;
    import std.array: array;

    if(shouldSkip(cursor.spelling, context))
        return [];

    if(cursor.spelling == "")
        throw new UntranslatableException("BUG: namespace with no name");

    if(cantTranslate(cursor.spelling))
        throw new UntranslatableException("Currently unsupported namespace");


    string[] lines;

    lines ~= [
            `extern(C++, "` ~ cursor.spelling ~ `")`,
            `{`,
    ];

    context.pushNamespace(cursor.spelling);
    scope(exit) context.popNamespace(cursor.spelling);

    auto children = () @trusted { return trueCursors(cast(Cursor[]) cursor.children); }();

    foreach(child; children) {

        if(child.kind == Cursor.Kind.VisibilityAttr) continue;

        lines ~= translate(child, context)
            .map!(a => (child.kind == Cursor.Kind.Namespace ? "    " : "        ") ~ a)
            .array;
    }

    lines ~= `}`;

    return lines;
}


private bool cantTranslate(in string spelling) @safe pure {
    import std.algorithm: endsWith;

    // FIXME
    return spelling.endsWith("detail");
}


private bool shouldSkip(in string spelling, in from!"dpp.runtime.context".Context context)
    @safe pure
{
    import std.algorithm: canFind;
    return context.options.ignoredNamespaces.canFind(spelling);
}
