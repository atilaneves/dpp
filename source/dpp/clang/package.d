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
