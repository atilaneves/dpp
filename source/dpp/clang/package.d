/**
   libclang utility code
 */
module dpp.clang;


import dpp.from;


from!"clang".Cursor namespace(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor;

    auto ret = Cursor(cursor.cx);

    while(!ret.isInvalid && ret.kind != Cursor.Kind.Namespace)
        ret = ret.semanticParent;

    return ret;
}


/**
   Returns the type name without namespaces.
 */
string typeNameNoNs(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor;
    import std.array: join;
    import std.algorithm: reverse;

    string[] parts;

    auto c = Cursor(cursor.cx);

    bool isWanted(in Cursor c) {
        return
            !c.isInvalid
            && c.kind != Cursor.Kind.Namespace
            && c.kind != Cursor.Kind.TranslationUnit
            ;
    }

    while(isWanted(c.semanticParent)) {
        c = c.semanticParent;
        parts ~= c.spelling.idup;
    }

    parts = parts.reverse ~ cursor.spelling;

    return parts.join("::");
}


/**
   If the cursor is a virtual function that overrides
   another virtual function.
 */
bool isOverride(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor;
    import std.algorithm: any, map, filter, joiner;

    bool hasOverrideAttr(in Cursor cursor) {
        return cursor
            .children
            .any!(a => a.kind == Cursor.Kind.CXXOverrideAttr)
            ;
    }

    if(hasOverrideAttr(cursor)) return true;

    auto parents = baseClasses(cursor.semanticParent);
    const virtualWithSameName = parents
        .map!(a => a.children)
        .joiner
        .filter!(a => a.spelling == cursor.spelling)
        .any!(a => a.isVirtual)
        ;

    return virtualWithSameName;
}


/**
   If the cursor is a `final` member function.
 */
bool isFinal(in from!"clang".Cursor cursor) @safe nothrow {
    import clang: Cursor;
    import std.algorithm: any;

    return cursor
        .children
        .any!(a => a.kind == Cursor.Kind.CXXFinalAttr)
        ;
}


/**
   All base classes this cursor derives from
 */
from!"clang".Cursor[] baseClasses(in from!"clang".Cursor cursor) @safe nothrow {
    import clang: Cursor;
    import std.algorithm: map, filter, joiner;
    import std.array: array;
    import std.range: chain;

    auto baseSpecifiers = cursor
        .children
        .filter!(a => a.kind == Cursor.Kind.CXXBaseSpecifier);
    if(baseSpecifiers.empty) return [];

    auto baseCursors = baseSpecifiers.map!(a => a.children[0].referencedCursor);
    return chain(
        baseCursors,
        baseCursors.map!baseClasses.joiner,
    ).array;
}
