module dpp.translation.namespace;

import dpp.from;


bool hasNewExternCpp() @safe @pure
{
    version(NewExternCpp)
    {
        return  __traits(compiles,`extern(C++) extern(C++,"Foo","Bar","Indeed")`));
    }
    {
        else return false;
    }
}

string[] translateNamespace(in from!"clang".Cursor cursor,
                            ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.translation: translate, ignoredCppCursorSpellings;
    import dpp.util:safeArray;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map, canFind, startsWith;
    import std.array: array;
    import std.algorithm: map,filter,canFind, startsWith,count,sort;
    import std.string:strip;
    import std.array: array,join,front;
    import std.format:format;

    assert(cursor.kind == Cursor.Kind.Namespace);

    string[] bodyLines;

    context.log("opening new namespace from ",context.getNamespace, " and adding ",cursor.spelling,cursor);
    context.pushNamespace(cursor.spelling);

    static if (hasNewExternCpp())
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
    import std.exception:enforce;
    enforce(from!"std.algorithm".all!(c => c.kind = from!"clang".Cursor.Kind.Namespace)(cursorChunkGroup));
    cursorChunkGroup.each!(c=>enforce(c.spelling == cursorChunkGroup.front.spelling));
 }
 do
 {
    import std.algorithm:map,sort;
    import dpp.util:safeArray;
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
in
{
    from!"std.exception".enforce(from!"std.algorithm".all!(c=>c.kind == from!"clang".Cursor.Kind.Namespace)(cursors));
}
do
{
    import std.algorithm:map,sort;
    import dpp.util:safeArray, mutableT;
    return cursors
        .map!(c => mutableT(c))
        .safeArray
        .sort!((a,b) =>(a.spelling<b.spelling))
        .safeArray
        .chunkByTrusted!((a,b) => (a.spelling == b.spelling));
}


private auto chunkByTrusted(alias f,T)(T[] arg) @trusted
{
    import dpp.util:safeArray;
    import std.algorithm:chunkBy,map;
    import std.array:Appender;
    Appender!(T[][]) ret;
    //destructor of return of chunkyBy is @system
    import dpp.util:safeArray;
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

