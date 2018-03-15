module ut.translation.function_;

import ut.translation;

@("struct Foo addFoos(struct Foo* foo1, struct Foo* foo2)")
@safe pure unittest {

    auto function_ = Cursor.functionDecl("addFoos",
                                         "struct Foo (struct Foo*, struct Foo*)",
                                         Type(Type.Kind.Elaborated, "struct Foo"));

    function_.children = [
        Cursor(Cursor.Kind.TypeRef,
               "struct Foo",
               Type(Type.Kind.Record, "struct Foo")),
        Cursor(Cursor.Kind.ParmDecl,
               "foo1",
               Type(Type.Kind.Pointer, "struct Foo *")),
        Cursor(Cursor.Kind.ParmDecl,
               "foo1",
               Type(Type.Kind.Pointer, "struct Foo *")),
    ];

    translateFunction(function_).shouldEqual(
        [
            q{Foo addFoos(Foo *, Foo *);},
        ]
    );
}

@("struct Bar addBars(struct Bar* foo1, struct Bar* foo2)")
@safe pure unittest {

    auto function_ = Cursor.functionDecl("addBars",
                                         "struct Bar (struct Bar*, struct Bar*)",
                                         Type(Type.Kind.Elaborated, "struct Bar"));

    function_.children = [
        Cursor(Cursor.Kind.TypeRef,
               "struct Bar",
               Type(Type.Kind.Record, "struct Bar")),
        Cursor(Cursor.Kind.ParmDecl,
               "foo1",
               Type(Type.Kind.Pointer, "struct Bar *")),
        Cursor(Cursor.Kind.ParmDecl,
               "foo1",
               Type(Type.Kind.Pointer, "struct Bar *")),
    ];

    translateFunction(function_).shouldEqual(
        [
            q{Bar addBars(Bar *, Bar *);},
        ]
    );
}

@("struct Bar addBars(const struct Bar* foo1, const struct Bar* foo2)")
@safe pure unittest {

    auto function_ = Cursor.functionDecl("addBars",
                                         "struct Bar (const struct Bar*, const struct Bar*)",
                                         Type(Type.Kind.Elaborated, "struct Bar"));

    function_.children = [
        Cursor(Cursor.Kind.TypeRef,
               "struct Bar",
               Type(Type.Kind.Record, "struct Bar")),
        Cursor(Cursor.Kind.ParmDecl,
               "foo1",
               Type(Type.Kind.Pointer, "const struct Bar *")),
        Cursor(Cursor.Kind.ParmDecl,
               "foo1",
               Type(Type.Kind.Pointer, "const struct Bar *")),
    ];

    translateFunction(function_).shouldEqual(
        [
            q{Bar addBars(const Bar *, const Bar *);},
        ]
    );
}

@("const char *nn_strerror (int errnum)")
@safe pure unittest {
    auto function_ = Cursor.functionDecl("nn_strerror",
                                         "const char *(int)",
                                         Type(Type.Kind.Pointer, "const char *"));
    function_.children = [ Cursor(Cursor.Kind.ParmDecl, "errnum", Type(Type.Kind.Int, "int")) ];

    translateFunction(function_).shouldEqual(
        [
            q{const(char)* nn_strerror(int);}
        ]
    );
}
