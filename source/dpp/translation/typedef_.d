/**
   typedef translations
 */
module dpp.translation.typedef_;

import dpp.from;

string[] translateTypedef(in from!"dpp.ast.node".Node node,
                          ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.algorithm: filter;
    import std.array: array;

    const children = () @trusted {
        return node
        .children
        .filter!(a => !a.isInvalid)
        // ???
        .filter!(a => a.kind != Cursor.Kind.FirstAttr)
        .array;
    }();

    context.log("Children: ", children);
    context.log("Underlying type: ", node.underlyingType);

    // FIXME - why canonical?
    if(isSomeFunction(node.underlyingType.canonical))
        return translateFunctionTypeDef(node, context.indent);

    const isTopLevelAnonymous =
        children.length == 1 && // so we can inspect it
        children[0].spelling == "" && // anonymous
        children[0].lexicalParent.kind == Cursor.Kind.TranslationUnit; // top-level

    // if the child is a top-level anonymous struct, it's pointless to alias
    // it and give the struct a silly name, instead just define a struct with
    // the typedef name instead. e.g.
    // `typedef struct { int dummy; } Foo` -> `struct Foo { int dummy; }`
    // However, this isn't true for enums since an anonymous enum can be declared
    // with no typedef. See #54.
    if(isTopLevelAnonymous && children[0].kind != Cursor.Kind.EnumDecl)
        return translateTopLevelAnonymous(children[0], context);

    return translateRegularTypedef(node, context, children);
}


private string[] translateRegularTypedef(in from!"clang".Cursor typedef_,
                                         ref from!"dpp.runtime.context".Context context,
                                         in from!"clang".Cursor[] children)
    @safe
{
    import dpp.translation.type: translate;
    import dpp.translation.aggregate: isAggregateC;
    import dpp.translation.dlang: maybeRename;
    import std.typecons: No;

    const underlyingSpelling = () {
        switch(typedef_.spelling) {
        default:
            // FIXME - still not sure I understand isOnlyAggregateChild here
            const isOnlyAggregateChild = children.length == 1 && isAggregateC(children[0]);
            return isOnlyAggregateChild
                ? context.spellingOrNickname(children[0])
                : translate(typedef_.underlyingType, context, No.translatingFunction);

        // possible issues on 32-bit
        case "int32_t":  return "int";
        case "uint32_t": return "uint";
        case "in64_t":   return "long";
        case "uint64_t": return "ulong";
        }
    }();

    context.rememberType(typedef_.spelling);

    context.log("");

    // This used to be due to `typedef struct foo { } foo`, but now it's not.
    // Changing this to always alias however breaks:
    // it.c.compile.projects.const char* const
    // it.c.compile.projects.struct with union
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
    import dpp.ast.node: Node;
    import clang: Cursor;

    // the old cursor has no spelling, so construct a new one
    auto newCursor = Cursor(cursor.cx);

    // the type spelling will be the name of the struct, union, or enum
    newCursor.spelling = cursor.type.spelling;

    // delegate to whoever knows what they're doing
    return translate(const Node(newCursor), context);
}
