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
        parts ~= c.spelling;
    }

    parts = parts.reverse ~ cursor.spelling;

    return parts.join("::");
}
