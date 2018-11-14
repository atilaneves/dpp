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

    auto structs = tu.children[0 .. 4];     // Foo, Bar, Baz, Quux
    auto template_ = tu.children[4];        // The full or pure template
    auto partials = tu.children[5 .. 7];    // The partial template specialisations
    auto full = tu.children[7]; // The last Template declaration

    foreach(struct_; structs) {
        struct_.kind.should == Cursor.Kind.StructDecl;
        struct_.type.numTemplateArguments.should == -1;
    }

    template_.kind.should == Cursor.Kind.ClassTemplate;
    // The actual template, according to clang, has no template arguments
    template_.type.numTemplateArguments.should == -1;
    // To get the template parameters, one must look at the ClassTemplate's children
    template_.children.length.should == 7;
    printChildren(template_);

    const typeAliasDecl = template_.children[$ - 1];
    typeAliasDecl.kind.should == Cursor.Kind.TypeAliasDecl;

    const templateParameters = template_.children[0 .. $ - 1];
    templateParameters[0].kind.should == Cursor.Kind.TemplateTypeParameter;
    templateParameters[1].kind.should == Cursor.Kind.TemplateTypeParameter;
    templateParameters[2].kind.should == Cursor.Kind.NonTypeTemplateParameter;
    templateParameters[3].kind.should == Cursor.Kind.TemplateTypeParameter; // bool
    templateParameters[4].kind.should == Cursor.Kind.NonTypeTemplateParameter;
    templateParameters[5].kind.should == Cursor.Kind.TemplateTypeParameter; // int

    foreach(partial; partials) {
        partial.kind.should == Cursor.Kind.ClassTemplatePartialSpecialization;
        partial.type.numTemplateArguments.should == 6;
        partial.specializedCursorTemplate.should == template_;
    }

    full.kind.should == Cursor.Kind.StructDecl;
    full.type.numTemplateArguments.should == 6;
}



@Tags("contract")
@("variadic.only.types")
@safe unittest {
    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<typename...>
                struct Variadic {};
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const variadic = tu.children[0];
    printChildren(variadic);

    variadic.kind.should == Cursor.Kind.ClassTemplate;
    variadic.type.numTemplateArguments.should == -1;

    // variadic templates can't use the children to figure out how many template
    // arguments there are, since there's only one "typename" and the length
    // can be any number.
    variadic.children.length.should == 1;
    const templateParameter = variadic.children[0];

    templateParameter.kind.should == Cursor.Kind.TemplateTypeParameter;
    templateParameter.type.kind.should == Type.Kind.Unexposed;
    templateParameter.type.canonical.kind.should == Type.Kind.Unexposed;
    templateParameter.type.spelling.should == "type-parameter-0-0";

    Token(Token.Kind.Punctuation, "...").should.be in variadic.tokens;
}

@Tags("contract")
@("variadic.only.values")
@safe unittest {
    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<int...>
                struct Variadic {};
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const variadic = tu.children[0];
    printChildren(variadic);

    variadic.kind.should == Cursor.Kind.ClassTemplate;
    variadic.type.numTemplateArguments.should == -1;

    // variadic templates can't use the children to figure out how many template
    // arguments there are, since there's only one "typename" and the length
    // can be any number.
    variadic.children.length.should == 1;
    const templateParameter = variadic.children[0];

    templateParameter.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    templateParameter.type.kind.should == Type.Kind.Int;
    templateParameter.type.canonical.kind.should == Type.Kind.Int;
    templateParameter.type.spelling.should == "int";

    Token(Token.Kind.Punctuation, "...").should.be in variadic.tokens;
}

@Tags("contract")
@("variadic.also.types")
@safe unittest {
    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<int, typename, bool, typename...>
                struct Variadic {};
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const variadic = tu.children[0];
    printChildren(variadic);

    variadic.kind.should == Cursor.Kind.ClassTemplate;
    variadic.type.numTemplateArguments.should == -1;

    // variadic templates can't use the children to figure out how many template
    // arguments there are, since there's only one "typename" and the length
    // can be any number.
    variadic.children.length.should == 4;
    const intParam = variadic.children[0];
    const typeParam = variadic.children[1];
    const boolParam = variadic.children[2];
    const restParam = variadic.children[3];

    intParam.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    intParam.type.kind.should == Type.Kind.Int;

    typeParam.kind.should == Cursor.Kind.TemplateTypeParameter;
    typeParam.type.kind.should == Type.Kind.Unexposed;
    typeParam.spelling.should == "";

    boolParam.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    boolParam.type.kind.should == Type.Kind.Bool;

    restParam.kind.should == Cursor.Kind.TemplateTypeParameter;
    restParam.type.kind.should == Type.Kind.Unexposed;
    restParam.type.spelling.should == "type-parameter-0-3";

    Token(Token.Kind.Punctuation, "...").should.be in variadic.tokens;
}

@Tags("contract")
@("variadic.also.values")
@safe unittest {
    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<int, typename, bool, short...>
                struct Variadic {};
            }
        )
    );

    tu.children.length.shouldEqual(1);

    const variadic = tu.children[0];
    printChildren(variadic);

    variadic.kind.should == Cursor.Kind.ClassTemplate;
    variadic.type.numTemplateArguments.should == -1;

    // variadic templates can't use the children to figure out how many template
    // arguments there are, since there's only one "typename" and the length
    // can be any number.
    variadic.children.length.should == 4;
    const intParam = variadic.children[0];
    const typeParam = variadic.children[1];
    const boolParam = variadic.children[2];
    const restParam = variadic.children[3];

    intParam.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    intParam.type.kind.should == Type.Kind.Int;

    typeParam.kind.should == Cursor.Kind.TemplateTypeParameter;
    typeParam.type.kind.should == Type.Kind.Unexposed;
    typeParam.spelling.should == "";

    boolParam.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    boolParam.type.kind.should == Type.Kind.Bool;

    restParam.kind.should == Cursor.Kind.NonTypeTemplateParameter;
    restParam.type.kind.should == Type.Kind.Short;
    restParam.type.spelling.should == "short";

    Token(Token.Kind.Punctuation, "...").should.be in variadic.tokens;
}



@Tags("contract", "notravis")
@("variadic.specialization")
@safe unittest {
    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<typename...>
                struct Variadic {};

                template<typename T0, typename T1>
                struct Variadic<T0, T1> { };
            }
        )
    );

    tu.children.length.shouldEqual(2);

    const template_ = tu.children[0];
    printChildren(template_);

    const special = tu.children[1];
    printChildren(special);

    special.kind.should == Cursor.Kind.ClassTemplatePartialSpecialization;
    special.type.numTemplateArguments.should == 2;
    // unexposed - non-specialised type
    special.type.typeTemplateArgument(0).kind.should == Type.Kind.Unexposed;
    special.type.typeTemplateArgument(1).kind.should == Type.Kind.Unexposed;
}


@Tags("contract")
@("lref")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                template<typename>
                struct Struct{};

                template<typename T>
                struct Struct<T&> {
                    using Type = T;
                };
            }
        )
    );

    tu.children.length.shouldEqual(2);

    const general = tu.children[0];
    const special = tu.children[1];

    general.kind.should == Cursor.Kind.ClassTemplate;
    special.kind.should == Cursor.Kind.ClassTemplatePartialSpecialization;

    special.type.kind.should == Type.Kind.Unexposed;
    special.type.numTemplateArguments.should == 1;
    const templateType = special.type.typeTemplateArgument(0);

    templateType.spelling.should == "type-parameter-0-0 &";
}


@Tags("contract")
@("ParmDecl")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                template<typename> struct Struct{};
                template<typename R, typename... A>
                struct Struct<R(A...)> {};
            }
        )
    );

    tu.children.length.should == 2;
    const partial = tu.children[1];

    partial.kind.should == Cursor.Kind.ClassTemplatePartialSpecialization;
    printChildren(partial);
    partial.children.length.should == 4;

    partial.children[0].kind.should == Cursor.Kind.TemplateTypeParameter;
    partial.children[0].spelling.should == "R";

    partial.children[1].kind.should == Cursor.Kind.TemplateTypeParameter;
    partial.children[1].spelling.should == "A";

    partial.children[2].kind.should == Cursor.Kind.TypeRef;
    partial.children[2].spelling.should == "R";

    partial.children[3].kind.should == Cursor.Kind.ParmDecl;
    partial.children[3].spelling.should == "";

    const parmDecl = partial.children[3];
    parmDecl.type.kind.should == Type.Kind.Unexposed;
    parmDecl.type.spelling.should == "A...";
}

@Tags("contract")
@("ctor.copy.definition.only")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                template<typename T>
                struct Struct{
                    Struct(const Struct& other) {}
                };
            }
        )
    );

    tu.children.length.should == 1;

    const struct0 = tu.children[0];
    struct0.kind.should == Cursor.Kind.ClassTemplate;
    printChildren(struct0);
    struct0.children.length.should == 2;

    const templateParam0 = struct0.children[0];
    printChildren(templateParam0);
    templateParam0.kind.should == Cursor.Kind.TemplateTypeParameter;
    // We named it so it shows up as T, not as type-parameter-0-0
    templateParam0.type.spelling.should == "T";

    const ctor = struct0.children[1];
    printChildren(ctor);
    ctor.kind.should == Cursor.Kind.Constructor;

    ctor.children.length.should == 2;
    const ctorParam = ctor.children[0];
    ctorParam.kind.should == Cursor.Kind.ParmDecl;
    ctorParam.type.kind.should == Type.Kind.LValueReference;
    // The spelling here is different from the other test below
    ctorParam.type.spelling.should == "const Struct<T> &";
}


@Tags("contract")
@("ctor.copy.definition.declaration")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                template <typename> struct Struct;

                template<typename T>
                struct Struct{
                    Struct(const Struct& other) {}
                };
            }
        )
    );

    tu.children.length.should == 2;

    const struct0 = tu.children[0];
    struct0.kind.should == Cursor.Kind.ClassTemplate;
    printChildren(struct0);
    struct0.children.length.should == 1;

    const templateParam0 = struct0.children[0];
    templateParam0.kind.should == Cursor.Kind.TemplateTypeParameter;
    templateParam0.type.spelling.should == "type-parameter-0-0";

    const struct1 = tu.children[1];
    struct1.kind.should == Cursor.Kind.ClassTemplate;
    printChildren(struct1);
    struct1.children.length.should == 2;

    const templateParam1 = struct1.children[0];
    printChildren(templateParam1);
    templateParam1.kind.should == Cursor.Kind.TemplateTypeParameter;
    templateParam1.type.spelling.should == "T";

    const ctor = struct1.children[1];
    printChildren(ctor);
    ctor.kind.should == Cursor.Kind.Constructor;
    ctor.templateParams.length.should == 0;  // not a template function
    ctor.semanticParent.templateParams.length.should == 1;  // the `T`
    ctor.semanticParent.templateParams[0].spelling.should == "T";

    ctor.children.length.should == 2;
    const ctorParam = ctor.children[0];
    ctorParam.kind.should == Cursor.Kind.ParmDecl;
    ctorParam.type.kind.should == Type.Kind.LValueReference;

    // The spelling here is different from the other test above.
    // The class template type paramater is spelled "T" but the _same_
    // generic type as a part of a function parameter list gets spelled
    // "type-parameter-0-0" just because the original definition left out
    // the type parameter name.

    ctorParam.type.spelling.should == "const Struct<type-parameter-0-0> &";
    ctorParam.type.canonical.spelling.should == "const Struct<type-parameter-0-0> &";
}


@Tags("contract")
@("pointer to T")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                template<typename T>
                struct Struct {
                    T* data;
                };
            }
        )
    );

    tu.children.length.should == 1;
    const struct_ = tu.children[0];
    printChildren(struct_);

    struct_.kind.should == Cursor.Kind.ClassTemplate;
    struct_.spelling.should == "Struct";
    struct_.children.length.should == 2;

    struct_.children[0].kind.should == Cursor.Kind.TemplateTypeParameter;
    struct_.children[0].spelling.should == "T";

    const data = struct_.children[1];
    data.kind.should == Cursor.Kind.FieldDecl;
    data.spelling.should == "data";
    data.type.kind.should == Type.Kind.Pointer;
    data.type.spelling.should == "T *";
    data.type.pointee.kind.should == Type.Kind.Unexposed;
    data.type.pointee.spelling.should == "T";
}

@Tags("contract")
@("enum")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                template<int I> struct Struct { enum { value = I }; };
            }
        )
    );

    tu.children.length.should == 1;
    const template_ = tu.children[0];
    printChildren(template_);

    template_.kind.should == Cursor.Kind.ClassTemplate;
    template_.children.length.should == 2;
    template_.children[0].kind.should == Cursor.Kind.NonTypeTemplateParameter;

    const enumDecl = template_.children[1];
    enumDecl.kind.should == Cursor.Kind.EnumDecl;
    printChildren(enumDecl);

    enumDecl.children.length.should == 1;
    const enumConstantDecl = enumDecl.children[0];
    enumConstantDecl.kind.should == Cursor.Kind.EnumConstantDecl;
    enumConstantDecl.spelling.should == "value";
    enumConstantDecl.enumConstantValue.should == 0;  // it's a template
    writelnUt(enumConstantDecl.tokens);
}


@Tags("contract")
@("value template argument specialisation")
@safe unittest {

    import clang: Token;

    const tu = parse(
        Cpp(
            q{
                template<int I> struct Struct { enum { value = I }; };
                template<> struct Struct<42> { using Type = void; };
            }
        )
    );

    tu.children.length.should == 2;
    const template_ = tu.children[0];
    template_.kind.should == Cursor.Kind.ClassTemplate;
    const struct_ = tu.children[1];
    struct_.kind.should == Cursor.Kind.StructDecl;
    printChildren(struct_);

    struct_.children.length.should == 2;
    const integerLiteral = struct_.children[0];
    integerLiteral.kind.should == Cursor.Kind.IntegerLiteral;
    integerLiteral.spelling.should == "";

    integerLiteral.tokens.should == [Token(Token.Kind.Literal, "42")];
}
