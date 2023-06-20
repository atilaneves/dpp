module it.docs;

import it;
import dpp.translation;
import unit_threaded: shouldEqual, Sandbox;

import std.file: readText;
import std.string: indexOf;

import unit_threaded.assertions: shouldBeIn;

auto normalizeLines(string text) {
    import std.string: strip, lineSplitter;
    import std.algorithm: map;
    import std.array: join;
    return text.lineSplitter().map!(line => line.strip()).join('\n');
}


version(Windows) {
    @("The Cpp documentation is preserved")
    @safe unittest {
        with(immutable IncludeSandbox()) {

            writeFile("hdr.hpp",
                      `
                          /** f1 doc */
                          void f1() {}

                          // f2 non-doc
                          void f2() {}

                          /// f3 doc
                          void f3() {}

                          /** variable1 doc */
                          int variable1 = 1 + 2;

                          /// variable2 doc
                          int variable2 = 1 + 2;

                          // variable3 non-doc
                          int variable3 = 1 + 2;


                          /** Struct1 doc */
                          struct Struct1 {

                            /** prop1 doc */
                            int prop1;

                            /** method1 doc */
                            void method1();
                          };


                          /** Enum1 doc */
                          enum Enum1 {
                            /** x doc */
                            x,
                            /// y doc
                            y,
                            // z non doc
                            z,
                          };

                          /** Type1 doc */
                          typedef int Type1;`);
            writeFile("main.dpp",
                      `
                          #include "hdr.hpp"
                      `);
            runPreprocessOnly(
                "--source-output-path",
                inSandboxPath("foo/bar"),
                "main.dpp",
            );

            auto originalText = readText(inSandboxPath("foo/bar/main.d"));
            auto needle = `extern(C++)
            {
                /** Type1 doc */
                alias Type1 = int;
                /** Enum1 doc */
                enum Enum1
                {
                    /** x doc */
                    x = 0,
                    /// y doc
                    y = 1,
                    /// y doc
                    z = 2,
                }
                enum x = Enum1.x;
                enum y = Enum1.y;
                enum z = Enum1.z;
                /** Struct1 doc */
                struct Struct1
                {
                    /** prop1 doc */
                    int prop1;
                    /** method1 doc */
                    pragma(mangle, "?method1@Struct1@@QEAAXXZ") void method1() @nogc nothrow;
                }

                pragma(mangle, "?variable3@@3HA") extern export __gshared int variable3;
                /// variable2 doc
                pragma(mangle, "?variable2@@3HA") extern export __gshared int variable2;
                /** variable1 doc */
                pragma(mangle, "?variable1@@3HA") extern export __gshared int variable1;
                /// f3 doc
                pragma(mangle, "?f3@@YAXXZ") void f3() @nogc nothrow;

                pragma(mangle, "?f2@@YAXXZ") void f2() @nogc nothrow;
                /** f1 doc */
                pragma(mangle, "?f1@@YAXXZ") void f1() @nogc nothrow;
            }`;
        needle.normalizeLines().shouldBeIn(originalText[originalText.indexOf("extern(C++)")..$].normalizeLines());

        }
    }
}

@("The C documentation is preserved")
@safe unittest {
    with(immutable IncludeSandbox()) {
        writeFile("hdr.h",
                  `
                      /** f1 doc */
                      void f1() {}

                      // f2 non-doc
                      void f2() {}

                      /// f3 doc
                      void f3() {}

                      /** variable1 doc */
                      int variable1 = 1 + 2;

                      /// variable2 doc
                      int variable2 = 1 + 2;

                      // variable3 non-doc
                      int variable3 = 1 + 2;


                      /** Struct1 doc */
                      struct Struct1 {

                        /** prop1 doc */
                        int prop1;
                      };


                      /** Enum1 doc */
                      enum Enum1 {
                        /** x doc */
                        x,
                        /// y doc
                        y,
                        // z non doc
                        z,
                      };

                      /** Type1 doc */
                      typedef int Type1;
                  `);
        writeFile("main.dpp",
                  `
                      #include "hdr.h"
                  `);
        runPreprocessOnly(
            "--source-output-path",
            inSandboxPath("foo/bar"),
            "main.dpp",
        );

        auto originalText = readText(inSandboxPath("foo/bar/main.d"));
        auto needle = `extern(C)
        {
            /** Type1 doc */
            alias Type1 = int;
            /** Enum1 doc */
            enum Enum1
            {
                /** x doc */
                x = 0,
                /// y doc
                y = 1,
                /// y doc
                z = 2,
            }
            enum x = Enum1.x;
            enum y = Enum1.y;
            enum z = Enum1.z;
            /** Struct1 doc */
            struct Struct1
            {
                /** prop1 doc */
                int prop1;
            }

            extern export __gshared int variable3;
            /// variable2 doc
            extern export __gshared int variable2;
            /** variable1 doc */
            extern export __gshared int variable1;
            /// f3 doc
            void f3() @nogc nothrow;

            void f2() @nogc nothrow;
            /** f1 doc */
            void f1() @nogc nothrow;
        }`;
        needle.normalizeLines().shouldBeIn(originalText[originalText.indexOf("extern(C)")..$].normalizeLines());
    }
}
