/**
   typedef translations
 */
module include.cursor.typedef_;

import include.from;

string[] translateTypedef(in from!"clang".Cursor typedef_,
                          ref from!"include.runtime.context".Context context)
    @safe
{
    import include.type: translate;
    import include.cursor.aggregate: spellingOrNickname, isAggregateC;
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

    const nonCanonicalUnderlyingType = typedef_.underlyingType;
    const underlyingType = nonCanonicalUnderlyingType.canonical;

    context.log("Children: ", children);
    context.log("          Underlying type: ", nonCanonicalUnderlyingType);
    context.log("Canonical underlying type: ", underlyingType);

    if(isSomeFunction(underlyingType))
        return translateFunctionTypeDef(typedef_, context.indent);

    // FIXME - still not sure I understand this
    const oneAggregateChild = children.length == 1 && isAggregateC(children[0]);

    const underlyingSpelling = oneAggregateChild
        ? spellingOrNickname(children[0], context)
        : translate(underlyingType, context, No.translatingFunction);

    return typedef_.spelling == underlyingSpelling
        ? []
        : [`alias ` ~ typedef_.spelling ~ ` = ` ~ underlyingSpelling  ~ `;`];
}

private string[] translateFunctionTypeDef(in from!"clang".Cursor typedef_,
                                          ref from!"include.runtime.context".Context context)
    @safe
{
    import include.type: translate;
    import include.cursor.function_: paramTypes;
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
