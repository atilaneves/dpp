module dpp.translation.namespace;

import dpp.from;

string[] translateNamespace(in from!"clang".Cursor cursor,
                            ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.translation: translate;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map;
    import std.array: array;

    string[] lines;

    lines ~= context.pushNamespace(cursor.spelling);

    foreach(child; cursor.children) {
        lines ~= translate(child, context)
            .map!(a => (child.kind == Cursor.Kind.Namespace ? "    " : "        ") ~ a)
            .array;
        if(child.kind != Cursor.Kind.Namespace)
        context.addNamespaceSymbol(child.spelling);
    }

    lines ~= context.popNamespace();

    return lines;
}
