/**
   typedef translations
 */
module dpp.translation.typedef_;

import dpp.from;

string[] translateTypedef(in from!"clang".Cursor typedef_,
                          ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.type: translate;
    import dpp.translation.aggregate: isAggregateC;
    import dpp.translation.dlang: maybeRename;
    import clang: Cursor, Type;
    import std.conv: text;
    import std.typecons: No;
    import std.algorithm: filter, startsWith;
    import std.array: array;

    const children = () @trusted {
        return typedef_
        .children
        .filter!(a => !a.isInvalid)
        .filter!(a => a.kind != Cursor.Kind.FirstAttr)
        .array;
    }();

    const nonCanonicalUnderlyingType = typedef_.underlyingType;
    const canonicalUnderlyingType = nonCanonicalUnderlyingType.canonical;

    context.log("Children: ", children);
    context.log("          Underlying type: ", nonCanonicalUnderlyingType);
    context.log("Canonical underlying type: ", canonicalUnderlyingType);

    if(isSomeFunction(canonicalUnderlyingType))
        return translateFunctionTypeDef(typedef_, context.indent);

    const isOnlyAggregateChild = children.length == 1 && isAggregateC(children[0]);
    const isTopLevelAnonymous =
        isOnlyAggregateChild &&
        children[0].spelling == "" && // anonymous
        children[0].lexicalParent.kind == Cursor.Kind.TranslationUnit; // top-level

    // if the child is a top-level anonymous struct, it's pointless to alias
    // it and give the struct a silly name, instead just define a struct with
    // the typedef name instead. e.g.
    // typedef struct { int dummy; } Foo -> struct Foo { int dummy; }
    // However, this isn't true for enums since an anonymous enum can be declared
    // with no typedef. See #54.
    if(isTopLevelAnonymous && children[0].kind != Cursor.Kind.EnumDecl)
        return translateTopLevelAnonymous(children[0], context);

    // See contract.typedef_.typedef to a template type parameter
    const isTypeParameter = canonicalUnderlyingType.spelling.startsWith("type-");

    // FIXME - still not sure I understand isOnlyAggregateChild here
    const underlyingSpelling = () {
        if(isOnlyAggregateChild) return context.spellingOrNickname(children[0]);
        const typeToUse = isTypeParameter ? nonCanonicalUnderlyingType : canonicalUnderlyingType;
        return translate(typeToUse, context, No.translatingFunction);
    }();

    context.rememberType(typedef_.spelling);

    // If the two spellings are the same, it's a `typedef struct foo { } foo`
    // situration, and there's no reason to alias to anything, so we return nothing.
    return typedef_.spelling == underlyingSpelling
        ? []
        : [`alias ` ~ maybeRename(typedef_, context) ~ ` = ` ~ underlyingSpelling  ~ `;`];
}

private string[] translateFunctionTypeDef(in from!"clang".Cursor typedef_,
                                          ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.type: translate;
    import dpp.translation.function_: translateParamTypes;
    import clang: Cursor, Type;
    import std.algorithm: map, filter;
    import std.array: join;

    const underlyingType = typedef_.underlyingType.canonical;
    const returnType = underlyingType.kind == Type.Kind.Pointer
        ? underlyingType.pointee.returnType
        : underlyingType.returnType;
    context.log("Function typedef return type: ", returnType);
    const returnTypeTransl = translate(returnType, context);

    const params = translateParamTypes(typedef_, context.indent).join(", ");
    return [`alias ` ~ typedef_.spelling ~ ` = ` ~ returnTypeTransl ~ ` function(` ~ params ~ `);`];

}

private bool isSomeFunction(in from!"clang".Type type) @safe pure nothrow {
    import clang: Type;

    const isFunctionPointer =
        type.kind == Type.Kind.Pointer &&
        type.pointee.kind == Type.Kind.FunctionProto;
    const isFunction = type.kind == Type.Kind.FunctionProto;

    return isFunctionPointer || isFunction;
}

private string[] translateTopLevelAnonymous(in from!"clang".Cursor cursor,
                                            ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.translation: translate;
    import clang: Cursor;

    // the old cursor has no spelling, so construct a new one
    auto newCursor = Cursor(cursor.cx);

    // the type spelling will be the name of the struct, union, or enum
    newCursor.spelling = cursor.type.spelling;

    // delegate to whoever knows what they're doing
    return translate(newCursor, context);
}
