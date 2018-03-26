module include.translation.typedef_;

import include.from;

string[] translateTypedef(in from!"clang".Cursor typedef_,
                          in from!"include.runtime.options".Options options =
                                 from!"include.runtime.options".Options())
    @safe
{
    import include.translation.type: cleanType, translate;
    import clang: Cursor, Type;
    import std.conv: text;
    import std.typecons: No;
    import std.algorithm: filter;
    import std.array: array;

    options.indent.log("TypedefDecl children: ", typedef_.children);
    options.indent.log("Underlying type: ", typedef_.underlyingType);
    options.indent.log("Canonical underlying type: ", typedef_.underlyingType.canonical);
    const underlyingType = typedef_.underlyingType.canonical;

    // FIXME - seems to be built-in
    if (typedef_.spelling == "size_t") return [];

    if(isSomeFunction(underlyingType))
        return translateFunctionTypeDef(typedef_);

    const children = () @trusted {
        return typedef_
        .children
        .filter!(a => !a.isInvalid)
        .filter!(a => a.kind != Cursor.Kind.FirstAttr)
        .array;
    }();

    assert(children.length == 1 ||
           (children.length == 0 && typedef_.type.kind == Type.Kind.Typedef),
           text("typedefs should only have 1 member, not ", children.length,
                "\n", typedef_, "\n", children));

    const originalSpelling = children.length
        ? getOriginalSpelling(typedef_)
        : translate(underlyingType, No.translatingFunction, options);

    return typedef_.spelling == originalSpelling.cleanType
        ? []
        : [`alias ` ~ typedef_.spelling ~ ` = ` ~ originalSpelling.cleanType  ~ `;`];
}

private string[] translateFunctionTypeDef(in from!"clang".Cursor typedef_)
    @safe
{
    import include.translation.type: translate;
    import include.translation.function_: paramTypes;
    import clang: Cursor, Type;
    import std.algorithm: map, filter;
    import std.array: join;

    const underlyingType = typedef_.underlyingType.canonical;
    const returnType = underlyingType.kind == Type.Kind.Pointer
        ? translate(underlyingType.pointee.returnType)
        : translate(underlyingType.returnType);

    const params = paramTypes(typedef_).join(", ");
    return [`alias ` ~ typedef_.spelling ~ ` = ` ~ returnType ~ ` function(` ~ params ~ `);`];

}

private bool isSomeFunction(in from!"clang".Type type) @safe @nogc pure nothrow {
    import clang: Type;

    const isFunctionPointer =
        type.kind == Type.Kind.Pointer &&
        type.pointee.kind == Type.Kind.FunctionProto;
    const isFunction = type.kind == Type.Kind.FunctionProto;

    return isFunctionPointer || isFunction;
}

// FIXME
private string getOriginalSpelling(in from!"clang".Cursor typedef_) @safe {
    import include.translation.aggregate: spellingOrNickname;
    switch(typedef_.spelling) {
        default: return spellingOrNickname(typedef_.children[0]);
        case "u_int128_t": return "ulong";
        case "u_int64_t": return "ulong";
        case "u_int32_t": return "uint";
        case "u_int16_t": return "ushort";
        case "u_int8_t": return "ubyte";
        case "register_t": return "ulong";
    }
}
