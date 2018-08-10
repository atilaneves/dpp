module contract.templates;


import contract;


@Tags("contract")
@("Partial and full template specialisation")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                struct Foo; struct Bar; struct Baz; struct Quux;

                template<typename, typename, bool, typename, int, typename>
                struct Template { using Type = bool; };

                template<typename T, bool V0, typename T3, typename T4>
                struct Template<Quux, T, V0, T3, 42, T4> { using Type = short; };

                template<typename T, bool V0, typename T3, typename T4>
                struct Template<T, Quux, V0, T3, 42, T4> { using Type = double; };

                template<>
                struct Template<Quux, Baz, true, Bar, 33, Foo> { using Type = float; };
            }
        )
    );

    tu.children.length.shouldEqual(8);

    foreach(i; 0 .. 4) tu.children[i].kind.shouldEqual(Cursor.Kind.StructDecl);

    tu.children[4].kind.shouldEqual(Cursor.Kind.ClassTemplate);

    foreach(i; 5 .. 7) tu.children[i].kind.shouldEqual(Cursor.Kind.ClassTemplatePartialSpecialization);

    tu.children[7].kind.shouldEqual(Cursor.Kind.StructDecl);
}
