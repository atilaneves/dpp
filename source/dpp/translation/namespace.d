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
    import dpp.translation.aggregate: mutableCursor;
    import dpp.runtime.context:safeArray;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map,filter,canFind, startsWith,count,sort;
    import std.string:strip;
    import std.array: array,join,front;
    import std.format:format;

    assert(cursor.kind == Cursor.Kind.Namespace);

    string[] bodyLines;

    if (!context.isNamespaceSelected(context.getNamespace~"." ~ cursor.spelling))
        return [];

    context.log("opening new namespace from ",context.getNamespace, " and adding ",cursor.spelling,cursor);
    context.pushNamespace(cursor.spelling);


    static if ( __traits(compiles,`extern(C++) extern(C++,"Foo","Bar","Indeed")`))
    {
    	debug pragma(msg,"new namespace version");
    	string revisedSpelling = context.getNamespace
                    .splitNameSpaceSpelling
                    .map!(name => `"` ~ name ~ `"`)
                    .join(",");
    }
    else {
	    string revisedSpelling = `"` ~ cursor.spelling ~ `"`;
    }
    auto preludeLines = [
           `extern(C++, ` ~ revisedSpelling ~ `)`,
           `{`,
    ];

    auto nonNamespaceChildren =    cursor.children
                                        .filter!(c =>c.kind != Cursor.Kind.Namespace && c.kind != Cursor.Kind.VisibilityAttr);

    auto namespaceChildrenChunks = cursor.children
                    .filter!(c =>c.kind == Cursor.Kind.Namespace)
                    .safeArray
                    .chunk;
 
    bodyLines ~= nonNamespaceChildren
                    .map!(c => translate(c,context))
                    .safeArray
                    .join;

    foreach(ref childChunks; namespaceChildrenChunks) {
        auto mergedCursor = childChunks.mergeNamespaces;
        bodyLines ~= translate(mergedCursor,context).safeArray;
    }

    context.log("closing namespace: ",context.getNamespace,cursor.spelling,cursor);
    context.popNamespace();
    bodyLines = bodyLines.map!(line => "    " ~ line).safeArray;

    enum finLines = `}`;

    bool hasAnyBodyLines = (bodyLines.count!(l=>l.strip.length > 0)> 0);
    return hasAnyBodyLines ? preludeLines ~ bodyLines ~ finLines : [];
}

auto mergeNamespaces(from!"clang".Cursor[] cursorChunkGroup)
 in {
    import std.algorithm:each;
    import std.array:front;
    enforce(cursorChunkGroup.all!(c => c.kind = from!"clang".Cursor.Kind.Namespace));
    cursorChunkGroup.each!(c=>enforce(c.spelling == cursorChunkGroup.front.spelling));
 }
 do
 {
    import std.algorithm:map,sort;
    import dpp.runtime.context:safeArray;
    import std.array:front, join;
    auto mergedChunks = cursorChunkGroup
                .map!(c=>c.children)
                .safeArray
                .join
                .safeArray;
    auto mergedCursor = cursorChunkGroup.front;
    mergedCursor.children = mergedChunks;
    return mergedCursor;
 }
 
auto chunk(const from!"clang".Cursor[] cursors)
in { enforce(cursors.all!(c=>c.kind == from!"clang".Cursor.Kind.Namespace)); }
do
{
    import std.algorithm:map,sort;
    import dpp.runtime.context:safeArray;
    import dpp.translation.aggregate: mutableCursor;
    return cursors
        .map!(c => mutableCursor(c))
        .safeArray
        .sort!((a,b) =>(a.spelling<b.spelling))
        .safeArray
        .chunkByTrusted!((a,b) => (a.spelling == b.spelling));
}


private auto chunkByTrusted(alias f,T)(T[] arg) @trusted
{
    import dpp.runtime.context:safeArray;
    import std.algorithm:chunkBy,map;
    import std.array:Appender;
    Appender!(T[][]) ret;
    //destructor of return of chunkyBy is @system
    import dpp.runtime.context:safeArray;
    import std.algorithm:chunkBy,map;
    foreach(ref r;arg.chunkBy!f)
    {
        ret.put(r.safeArray);
    }
    return ret.data;
}

private string[] splitNameSpaceSpelling(string namespace) pure @safe
{
	import std.string:split;
	return namespace.split('.');
}

private const(T)[] sortConst(alias f,T)(const(T)[] arg)
{
    import std.algorithm:makeIndex,map;
    import std.array:array;
    auto index = new size_t[arg.length];
    makeIndex!f(arg,index);
    return index.map!(i => arg[i])
               .array;
}