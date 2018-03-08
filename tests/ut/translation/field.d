module ut.translation.field;

import ut.translation;
import include.translation.aggregate: translateField;


@("throws if not field")
@safe pure unittest {
    import core.exception: AssertError;
    translateField(Cursor(Cursor.Kind.StructDecl, "oops")).shouldThrow!AssertError;
}

@("int")
@safe pure unittest {
    translateField(Cursor(Cursor.Kind.FieldDecl, "foo", Type(Type.Kind.Int))).shouldEqual(["int foo;"]);
    translateField(Cursor(Cursor.Kind.FieldDecl, "bar", Type(Type.Kind.Int))).shouldEqual(["int bar;"]);
}


@("double")
@safe pure unittest {
    translateField(Cursor(Cursor.Kind.FieldDecl, "foo", Type(Type.Kind.Double))).shouldEqual(["double foo;"]);
    translateField(Cursor(Cursor.Kind.FieldDecl, "bar", Type(Type.Kind.Double))).shouldEqual(["double bar;"]);
}
