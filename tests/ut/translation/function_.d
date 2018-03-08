module ut.translation.function_;

import ut.translation;

@("struct Foo addFoos(struct Foo*, struct Foo*)")
@safe pure unittest {

    const function_ = Cursor(Cursor.Kind.FunctionDecl,
                             "addFoos",
                             Type(Type.Kind.FunctionProto, "struct Foo (struct Foo*, struct Foo*)"),
                             Type(Type.Kind.Elaborated, "struct Foo"));

    translateFunction(function_).shouldEqual(
        [
            q{Foo addFoos(Foo*, Foo*);},
        ]
    );
}
