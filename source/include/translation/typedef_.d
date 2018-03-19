module include.translation.typedef_;

import include.from;

string[] translateTypedef(in from!"clang".Cursor typedef_,
                          in from!"include.runtime.options".Options options =
                                 from!"include.runtime.options".Options())
    @safe
{
    import include.translation.aggregate: spellingOrNickname;
    import include.translation.type: cleanType, translate,
        translateFunctionPointerReturnType, translateFunctionProtoReturnType;
    import clang: Cursor, Type;
    import std.conv: text;
    import std.algorithm: any, map, filter, countUntil;
    import std.array: join;

    options.indent.log("TypedefDecl children: ", typedef_.children);
    options.indent.log("Underlying type: ", typedef_.underlyingType);
    options.indent.log("Canonical underlying type: ", typedef_.underlyingType.canonical);

    // function pointer typedef
    if((typedef_.underlyingType.kind == Type.Kind.Pointer || typedef_.underlyingType.kind == Type.Kind.FunctionProto) &&
       typedef_.children.length > 0 &&
       typedef_.children.any!(a => a.kind == Cursor.Kind.ParmDecl))
    {
        const returnType = typedef_.underlyingType.kind == Type.Kind.Pointer
            ? translateFunctionPointerReturnType(typedef_.underlyingType)
            : translateFunctionProtoReturnType(typedef_.underlyingType);

        const paramTypes = typedef_
            .children
            .filter!(a => a.kind == Cursor.Kind.ParmDecl)
            .map!(a => translate(a.type))
            .join(", ");
        return [`alias ` ~ typedef_.spelling ~ ` = ` ~ returnType ~ ` function(` ~ paramTypes ~ `);`];
    }

    assert(typedef_.children.length == 1 ||
           (typedef_.children.length == 0 && typedef_.type.kind == Type.Kind.Typedef),
           text("typedefs should only have 1 member, not ", typedef_.children.length,
                "\n", typedef_, "\n", typedef_.children));

    const originalSpelling = typedef_.children.length
        ? spellingOrNickname(typedef_.children[0])
        : translate(typedef_.underlyingType, options);

    return [`alias ` ~ typedef_.spelling ~ ` = ` ~ originalSpelling.cleanType  ~ `;`];
}
