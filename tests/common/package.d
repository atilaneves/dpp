module common;


void printChildren(T)(auto ref in T cursorOrTU) {
    import clang: TranslationUnit, Cursor;
    import std.traits: Unqual;

    static if(is(Unqual!T == TranslationUnit) || is(Unqual!T == Cursor)) {

        import unit_threaded.io: writelnUt;
        import std.algorithm: map;
        import std.array: join;
        import std.conv: text;

        static if(is(Unqual!T == TranslationUnit))
            const children = cursorOrTU.cursor.children;
        else
            const children = cursorOrTU.children;

        writelnUt("\n", cursorOrTU, " children:\n[\n", children.map!(a => text("    ", a)).join(",\n"));
        writelnUt("]\n");
    }
}


void shouldMatch(T, K)(T obj, in K kind, in string spelling, in string file = __FILE__, in size_t line = __LINE__) {
    import unit_threaded;
    static assert(is(K == T.Kind));
    obj.kind.shouldEqual(kind, file, line);
    obj.spelling.shouldEqual(spelling, file, line);
}
