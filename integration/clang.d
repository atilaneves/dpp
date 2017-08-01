module integration.clang;

import include.clang;
import clang.c.Index: CXTranslationUnit_Flags;
import unit_threaded;
import std.path: buildPath;


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


        // this is how using clang_visitChildren directly would give us
        // with CXChildVisit_Recurse
        const translationUnitCursor = const Cursor(fileName, Cursor.Kind.TranslationUnit);
        const foo = const Cursor("Foo", Cursor.Kind.StructDecl);
        const i = const Cursor("i", Cursor.Kind.FieldDecl);
        const addFoos = const Cursor("addFoos", Cursor.Kind.FunctionDecl);
        const return_ = const Cursor("struct Foo", Cursor.Kind.TypeRef);
        const foo1 = const Cursor("foo1", Cursor.Kind.ParmDecl);
        const foo1type = const Cursor("struct Foo", Cursor.Kind.TypeRef);
        const foo2 = const Cursor("foo2", Cursor.Kind.ParmDecl);
        const foo2type = const Cursor("struct Foo", Cursor.Kind.TypeRef);


        parse(fullFileName, CXTranslationUnit_Flags.CXTranslationUnit_None).cursors.shouldEqual(
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
