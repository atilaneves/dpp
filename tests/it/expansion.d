module it.expansion;


import it;
import common: printChildren, shouldMatch;
import dpp.expansion;
import clang: parse, TranslationUnit, Cursor, Type;
import std.conv: text;
import std.array: join;
import std.algorithm: map;


@("namespace")
@safe unittest {


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

                    namespace outer2 {
                        struct Quux { };
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


@("issue113")
@safe unittest {

    auto tu = () {
        with(immutable Sandbox()) {
            writeFile(
                "foo.cpp",
                q{
                    namespace ns1 {
                        namespace ns2 {
                            struct Struct;

                            template<typename T>
                                struct Template {
                            };

                            class Class;  // should be ignored but isn't
                            class Class: public Template<Struct> {
                                int i;
                            };
                        }
                    }
                });

            return parse(inSandboxPath("foo.cpp"));
        }
    }();

    const cursors = canonicalCursors(tu);
    writelnUt(cursors.map!text.join("\n"));
    cursors.length.should == 1;

    const ns1 = cursors[0];
    ns1.shouldMatch(Cursor.Kind.Namespace, "ns1");
    printChildren(ns1);
    ns1.children.length.should == 1;

    const ns2 = ns1.children[0];
    ns2.shouldMatch(Cursor.Kind.Namespace, "ns2");
    printChildren(ns2);
    ns2.children.map!(a => a.spelling).shouldBeSameSetAs(["Struct", "Template", "Class"]);
    ns2.children.length.should == 3;
}
