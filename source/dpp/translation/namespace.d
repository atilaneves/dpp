module dpp.translation.namespace;

import dpp.from;

string[] translateNamespace(in from!"clang".Cursor cursor,
                            ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.translation: translate, ignoredCppCursorSpellings;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map,canFind, startsWith,count;
    import std.string:strip;
    import std.array: array;

    assert(cursor.kind == Cursor.Kind.Namespace);

    string[] bodyLines;

    auto preludeLines = [
            `extern(C++, "` ~ cursor.spelling ~ `")`,
            `{`,
    ];

    foreach(child; cursor.children) {

        if(child.kind == Cursor.Kind.VisibilityAttr) continue;

        bodyLines ~= translate(child, context)
            .map!(a => (child.kind == Cursor.Kind.Namespace ? "    " : "        ") ~ a)
            .array;
    }

    enum finLines = `}`;

    bool hasAnyBodyLines = (bodyLines.count!(l=>l.strip.length > 0)> 0);
    return hasAnyBodyLines ? preludeLines ~ bodyLines ~ finLines : [];
}
