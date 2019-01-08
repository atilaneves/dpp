module contract.namespace;


import contract;



@Tags("contract")
@("struct")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                namespace ns {
                    struct Struct {

                    };
                }
            }
        )
    );

    tu.children.length.should == 1;
    const namespace = tu.children[0];
    namespace.kind.should == Cursor.Kind.Namespace;

    namespace.children.length.should == 1;
    const struct_ = namespace.children[0];
    struct_.kind.should == Cursor.Kind.StructDecl;

    struct_.spelling.should == "Struct";
    struct_.type.spelling.should == "ns::Struct";
}


@Tags("contract")
@("template.type.parameter")
@safe unittest {
    const tu = parse(
        Cpp(
            q{
                namespace ns {
                    struct Struct;
                    template<typename T>
                    struct Template { };
                    class Class: public Template<Struct> {
                        int i;
                    };
                }
            }
        )
    );

    tu.children.length.should == 1;
    const ns = tu.child(0);
    ns.shouldMatch(Cursor.Kind.Namespace, "ns");
    ns.type.shouldMatch(Type.Kind.Invalid, "");

    printChildren(ns);
    ns.children.length.should == 3;

    const struct_ = ns.child(0);
    struct_.shouldMatch(Cursor.Kind.StructDecl, "Struct");
    struct_.type.shouldMatch(Type.Kind.Record, "ns::Struct");
    printChildren(struct_);
    struct_.children.length.should == 0;

    const template_ = ns.child(1);
    template_.shouldMatch(Cursor.Kind.ClassTemplate, "Template");
    template_.type.shouldMatch(Type.Kind.Invalid, "");
    printChildren(template_);
    template_.children.length.should == 1;

    const class_ = ns.child(2);
    class_.shouldMatch(Cursor.Kind.ClassDecl, "Class");
    class_.type.shouldMatch(Type.Kind.Record, "ns::Class");
    printChildren(class_);
    class_.children.length.should == 2;

    const base = class_.child(0);
    base.shouldMatch(Cursor.Kind.CXXBaseSpecifier, "Template<struct ns::Struct>");
    base.type.shouldMatch(Type.Kind.Unexposed, "Template<ns::Struct>");
    base.type.canonical.shouldMatch(Type.Kind.Record, "ns::Template<ns::Struct>");
    printChildren(base);
    base.children.length.should == 2;

    const templateRef = base.child(0);
    templateRef.shouldMatch(Cursor.Kind.TemplateRef, "Template");
    templateRef.type.shouldMatch(Type.Kind.Invalid, "");
    templateRef.children.length.should == 0;

    const typeRef = base.child(1);
    typeRef.shouldMatch(Cursor.Kind.TypeRef, "struct ns::Struct");
    typeRef.type.shouldMatch(Type.Kind.Record, "ns::Struct");
    typeRef.type.canonical.shouldMatch(Type.Kind.Record, "ns::Struct");
    typeRef.children.length.should == 0;

    const i = class_.child(1);
    i.shouldMatch(Cursor.Kind.FieldDecl, "i");
    i.type.shouldMatch(Type.Kind.Int, "int");
    i.children.length.should == 0;
}
