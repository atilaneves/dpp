/**
   This module expands each header encountered in the original input file.
   It usually delegates to dstep but not always. Since dstep has a different
   goal, which is to produce human-readable D files from a header, we can't
   just call into it.

   The translate function here will handle the cases it knows how to deal with,
   otherwise it asks dstep to it for us.
 */

module include.translation;


import clang: TranslationUnit, Cursor, Type;



string translate(ref TranslationUnit translationUnit,
                 ref Cursor cursor,
                 ref Cursor parent)
    @safe
{
    import std.array: join;

    if(skipCursor(cursor)) return "";

    return translate(cursor).join("\n");
}

private bool skipCursor(ref Cursor cursor) @safe pure {
    import std.algorithm: startsWith, canFind;

    static immutable forbiddenSpellings =
        [
            "ulong", "ushort", "uint",
            "va_list", "__gnuc_va_list",
            "_IO_2_1_stdin_", "_IO_2_1_stdout_", "_IO_2_1_stderr_",
        ];

    return forbiddenSpellings.canFind(cursor.spelling) || cursor.isPredefined;
}


string[] translate(Cursor cursor) @safe {

    import std.conv: text;
    import std.array: join;

    switch(cursor.kind) with(Cursor.Kind) {
        default:
            return [];

        case StructDecl:
            string[] ret;

            ret ~= `struct Foo {`;
            foreach(field; cursor) {
                ret ~= translateField(field);
            }
            ret ~= `}`;

            return ret;

        case FunctionDecl:
            const returnType = "Foo";
            const name = "addFoos";
            const types = ["Foo*", "Foo*"];
            return [text(returnType, " ", name, "(", types.join(", "), ");")];
    }
}

string translate(in Type type) @safe pure {

    import std.conv: text;

    switch(type.kind) with(Type.Kind) {

        default:
            assert(false, text("Type kind ", type.kind, " not supported"));

        case Int:
            return "int";

        case Double:
            return "double";
    }
}


string translateField(in Cursor field) @safe pure {
    import std.conv: text;

    assert(field.kind == Cursor.Kind.FieldDecl);
    const type = translate(field.type);
    const name = field.spelling;
    return text(type, " ", name, ";");
}
