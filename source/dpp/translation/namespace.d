module dpp.translation.namespace;

import dpp.from;

string[] translateNamespace(in from!"clang".Cursor cursor,
                            ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.translation: translate, ignoredCppCursorSpellings;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map, canFind, startsWith;
    import std.array: array;

    assert(cursor.kind == Cursor.Kind.Namespace);

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
