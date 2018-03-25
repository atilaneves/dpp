module ut.translation.field;

import ut.translation;
import include.translation.aggregate: translateField;


@("throws if not field")
@safe unittest {
    import core.exception: AssertError;
    translateField(Cursor(Cursor.Kind.StructDecl, "oops")).shouldThrow!AssertError;
}

@("int")
@safe unittest {
    translateField(Cursor(Cursor.Kind.FieldDecl, "foo", Type(Type.Kind.Int))).shouldEqual(["int foo;"]);
    translateField(Cursor(Cursor.Kind.FieldDecl, "bar", Type(Type.Kind.Int))).shouldEqual(["int bar;"]);
}


@("double")
@safe unittest {
    translateField(Cursor(Cursor.Kind.FieldDecl, "foo", Type(Type.Kind.Double))).shouldEqual(["double foo;"]);
    translateField(Cursor(Cursor.Kind.FieldDecl, "bar", Type(Type.Kind.Double))).shouldEqual(["double bar;"]);
}

@("struct")
@safe unittest {
    auto type = Type.pointer("struct Foo *",
                             new Type(Type.Kind.Elaborated, "struct Foo"));
    translateField(Cursor(Cursor.Kind.FieldDecl, "foo", *type))
        .shouldEqual(["Foo* foo;"]);
}

@ShouldFail("Bug - translation doesn't work well in translatePointer")
@("const char* const")
@safe unittest {
    // pointer to const pointer to const char
    translateField(Cursor(Cursor.Kind.FieldDecl, " foo", Type(Type.Kind.Pointer, `const char * const *protocols`)))
        .shouldEqual(["const(char*)* protocotols"]);
}
