module it.expansion;


import it;
import dpp.expansion;


@("canonical.namespace")
@safe unittest {

    import contract: printChildren, shouldMatch;
    import clang: parse, TranslationUnit, Cursor, Type;
    import std.conv: text;
    import std.array: join;
    import std.algorithm: map;

    auto tu = () {

        with(immutable IncludeSandbox()) {
            writeFile(
                "foo.cpp",
                q{

                    int globalInt;
                    namespace outer1 {
                        namespace inner1 {
                            struct Foo;
                            struct Bar;

                            struct Baz {
                                int i;
                                double d;
                            };
                        }
                    }

                    namespace outer1 {
                        namespace inner1 {
                            struct Foo {
                                int i;
                            };

                            struct Bar {
                                double d;
                            };
                        }
                    }

                    namespace outer2 {
                        struct Quux { };
                    }
                });

            return parse(inSandboxPath("foo.cpp"));
        }
    }();

    const cursors = canonicalCursors(tu);
    writelnUt(cursors.map!text.join("\n"));
    cursors.length.should == 3;

    const globalInt = cursors[0];
    globalInt.shouldMatch(Cursor.Kind.VarDecl, "globalInt");

    const outer1 = cursors[1];
    outer1.shouldMatch(Cursor.Kind.Namespace, "outer1");
    printChildren(outer1);
    outer1.children.length.should == 1;

    const inner1 = outer1.children[0];
    inner1.shouldMatch(Cursor.Kind.Namespace, "inner1");
    printChildren(inner1);
    inner1.children.length.should == 3;
    inner1.children.map!(a => a.spelling).shouldBeSameSetAs(["Foo", "Bar", "Baz"]);

    const outer2 = cursors[2];
    outer2.shouldMatch(Cursor.Kind.Namespace, "outer2");
    printChildren(outer2);
    outer2.children.length.should == 1;

    const quux = outer2.children[0];
    quux.shouldMatch(Cursor.Kind.StructDecl, "Quux");
}
