module include.translation.typedef_;

import include.from;

string[] translateTypedef(in from!"clang".Cursor typedef_,
                          ref from!"include.runtime.context".Context context)
    @safe
{
    import include.translation.type: cleanType, translate;
    import include.translation.aggregate: spellingOrNickname;
    import clang: Cursor, Type;
    import std.conv: text;
    import std.typecons: No;
    import std.algorithm: filter;
    import std.array: array;

    const children = () @trusted {
        return typedef_
        .children
        .filter!(a => !a.isInvalid)
        .filter!(a => a.kind != Cursor.Kind.FirstAttr)
        .array;
    }();

    const underlyingType = typedef_.underlyingType.canonical;

    context.log("TypedefDecl children: ", children);
    context.log("Underlying type: ", underlyingType);
    context.log("Canonical underlying type: ", underlyingType.canonical);

    // FIXME - seems to be built-in
    if (typedef_.spelling == "size_t") return [];

    if(isSomeFunction(underlyingType))
        return translateFunctionTypeDef(typedef_, context.indent);

    assert(children.length == 1 || typedef_.type.kind == Type.Kind.Typedef,
           text("typedefs should only have 1 member, not ", children.length,
                "\n", typedef_, "\n", children));

    // FIXME
    // I'm not sure under which conditions the type has to be translated
    // Right now arrays are being special cased due to a pthread bug
    // (see the jmp_buf test)
    const translateType =
        children.length == 0 ||
        underlyingType.kind == Type.Kind.ConstantArray ||
        underlyingType.kind == Type.Kind.Pointer;

    const originalSpelling = translateType
        ? translate(underlyingType, context, No.translatingFunction)
        : spellingOrNickname(children[0], context);

    return typedef_.spelling == originalSpelling.cleanType
        ? []
        : [`alias ` ~ typedef_.spelling ~ ` = ` ~ originalSpelling.cleanType  ~ `;`];
}

private string[] translateFunctionTypeDef(in from!"clang".Cursor typedef_,
                                          ref from!"include.runtime.context".Context context)
    @safe
{
    import include.translation.type: translate;
    import include.translation.function_: paramTypes;
    import clang: Cursor, Type;
    import std.algorithm: map, filter;
    import std.array: join;

    const underlyingType = typedef_.underlyingType.canonical;
    const returnType = underlyingType.kind == Type.Kind.Pointer
        ? underlyingType.pointee.returnType
        : underlyingType.returnType;
    context.log("Function typedef return type: ", returnType);
    const returnTypeTransl = translate(returnType, context);

    const params = paramTypes(typedef_, context.indent).join(", ");
    return [`alias ` ~ typedef_.spelling ~ ` = ` ~ returnTypeTransl ~ ` function(` ~ params ~ `);`];

}

private bool isSomeFunction(in from!"clang".Type type) @safe @nogc pure nothrow {
    import clang: Type;

    const isFunctionPointer =
        type.kind == Type.Kind.Pointer &&
        type.pointee.kind == Type.Kind.FunctionProto;
    const isFunction = type.kind == Type.Kind.FunctionProto;

    return isFunctionPointer || isFunction;
}
