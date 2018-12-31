module dpp.translation.namespace;

import dpp.from;

struct NamespaceNode
{
	string name;
	string[] lines;
	NamespaceNode[] children;
}

string[] translateNamespace(in from!"clang".Cursor cursor,
                            ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.translation: translate, ignoredCppCursorSpellings;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map,canFind, startsWith,count;
    import std.string:strip;
    import std.array: array,join;
    import std.format:format;

    assert(cursor.kind == Cursor.Kind.Namespace);

    string[] bodyLines;

    static if ( __traits(compiles,`extern(C++) extern(C++,"Foo","Bar","Indeed")`))
    {
	debug pragma(msg,"new namespace version");
	string revisedSpelling = cursor.spelling.splitNameSpaceSpelling.join(",");
    }
    else {
	    string revisedSpelling = cursor.spelling;
    }
    auto preludeLines = [
            `extern(C++, "` ~ revisedSpelling ~ `")`,
            `{`,
    ];

    foreach(child; cursor.children) {
        context.log("opening new namespace from ",context.getNamespace, " and adding ",cursor.spelling,cursor);
        context.pushNamespace(cursor.spelling);

        if(child.kind == Cursor.Kind.VisibilityAttr) continue;

        bodyLines ~= translate(child, context)
            .map!(a => (child.kind == Cursor.Kind.Namespace ? "    " : "        ") ~ a)
            .array;
        context.log("closing namespace: ",context.getNamespace,cursor.spelling,cursor);
	context.popNamespace();
    }

    enum finLines = `}`;

    bool hasAnyBodyLines = (bodyLines.count!(l=>l.strip.length > 0)> 0);
    return hasAnyBodyLines ? preludeLines ~ bodyLines ~ finLines : [];
}

private string[] splitNameSpaceSpelling(string namespace) pure @safe
{
	import std.string:split;
	return namespace.split('.');
}
