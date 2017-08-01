module integration.clang;

import include.clang;
import clang.Cursor: ClangCursor = Cursor;
import clang.c.Index: CXCursorKind, CXTranslationUnit_Flags;
import unit_threaded;
import std.file: tempDir;
import std.path: buildPath;


struct Cursor {
    string spelling;
    CXCursorKind kind;
}


@("Simple translation unit")
@safe unittest {

    with(immutable Sandbox()) {

        const fileName = "simple_header.h";

        writeFile(fileName,
                  q{
                      struct Foo {
                          int i;
                      };
                      struct Foo addFoos(struct Foo* foo1, struct Foo* foo2);
                  });
        const fullFileName = buildPath(testPath, fileName);


        const translationUnitCursor = const Cursor(fileName, CXCursorKind.CXCursor_TranslationUnit);
        const foo = const Cursor("Foo", CXCursorKind.CXCursor_StructDecl);
        const i = const Cursor("i", CXCursorKind.CXCursor_FieldDecl);
        const addFoos = const Cursor("addFoos", CXCursorKind.CXCursor_FunctionDecl);
        const return_ = const Cursor("struct Foo", CXCursorKind.CXCursor_TypeRef);
        const foo1 = const Cursor("foo1", CXCursorKind.CXCursor_ParmDecl);
        const foo1type = const Cursor("struct Foo", CXCursorKind.CXCursor_TypeRef);
        const foo2 = const Cursor("foo2", CXCursorKind.CXCursor_ParmDecl);
        const foo2type = const Cursor("struct Foo", CXCursorKind.CXCursor_TypeRef);


        parse(fullFileName, CXTranslationUnit_Flags.CXTranslationUnit_None).cursors.shouldEqualCursors(
            [
                foo,
//                i,
                addFoos,
                // return_,
                // foo1,
                // foo1type,
                // foo2,
                // foo2type,
            ]
        );
    }
}


private void shouldEqualCursors(ClangCursor[] clangActual,
                                Cursor[] expected,
                                in string file = __FILE__,
                                in size_t line = __LINE__)
@trusted {
    import std.algorithm: map;
    clangActual.map!(a => Cursor(a.spelling, a.kind)).shouldEqual(expected, file, line);

}
