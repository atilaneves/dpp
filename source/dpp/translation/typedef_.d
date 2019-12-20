/**
   typedef translations
 */
module dpp.translation.typedef_;


import dpp.from;


string[] translateTypedef(in from!"clang".Cursor cursor,
                          ref from!"dpp.runtime.context".Context context)
    @safe
{
    // canonical because otherwise tests fail on Travis's version of libclang
    return isSomeFunction(cursor.underlyingType.canonical)
        ? translateFunction(cursor, context.indent)
        : translateNonFunction(cursor, context);
}


string[] translateNonFunction(in from!"clang".Cursor cursor,
                              ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor, Type;
    import std.algorithm: filter;
    import std.array: array;

    auto childrenRange = cursor
        .children
        .filter!(a => !a.isInvalid)
        // only interested in the actual type we're aliasing
        .filter!(a => a.type.kind != Type.Kind.Invalid)
        ;

    // who knows why this is @system
    const children = () @trusted { return childrenRange.array; }();

    // children might contain 0, 1, or more entries due to libclang particularities
    context.log("Children: ", children);
    context.log("Underlying type: ", cursor.underlyingType);

    // If the child is a top-level anonymous struct, it's pointless to alias
    // it and give the struct a silly name, instead just define a struct with
    // the typedef name instead. e.g.
    // `typedef struct { int dummy; } Foo` -> `struct Foo { int dummy; }`
    // However, this isn't true for enums since an anonymous enum can be declared
    // with no typedef. See #54.
    const noName = isTopLevelAnonymous(children) && children[0].kind != Cursor.Kind.EnumDecl;

    return noName
        ? translateTopLevelAnonymous(children[0], context)
        : translateRegular(cursor, context, children);
}


private bool isTopLevelAnonymous(in from!"clang".Cursor[] children)
    @safe nothrow
{
    import clang: Cursor;
    return
        children.length == 1 && // so we can inspect it
        children[0].spelling == "" && // anonymous
        children[0].lexicalParent.kind == Cursor.Kind.TranslationUnit // top-level
        ;
}

// non-anonymous non-function typedef
private string[] translateRegular(in from!"clang".Cursor cursor,
                                  ref from!"dpp.runtime.context".Context context,
                                  in from!"clang".Cursor[] children)
    @safe
{
    import dpp.translation.type: translate, removeDppDecorators;
    import dpp.translation.aggregate: isAggregateC;
    import dpp.translation.dlang: maybeRename;
    import std.typecons: No;

    const underlyingSpelling = () {
        switch(cursor.spelling) {
        default:
            // The cursor will have a type with spelling despite not having spelling itself.
            // We use the nickname we've given it in D if it's the case.
            const isAnonymousAggregate =
                children.length == 1 &&
                isAggregateC(children[0]) &&
                children[0].spelling == "";

            return isAnonymousAggregate
                ? context.spellingOrNickname(children[0])
                : translate(cursor.underlyingType, context, No.translatingFunction)
                    .removeDppDecorators;

        // possible issues on 32-bit
        case "int32_t":  return "int";
        case "uint32_t": return "uint";
        case "in64_t":   return "long";
        case "uint64_t": return "ulong";
        case "nullptr_t": return "typeof(null)";
        }
    }();

    context.rememberType(cursor.spelling);

    context.log("");

    // This is to prevent trying to translate `typedef struct Struct Struct;` which
    // makes no sense in D.
    return cursor.spelling == underlyingSpelling
        ? []
        : [`alias ` ~ maybeRename(cursor, context) ~ ` = ` ~ underlyingSpelling  ~ `;`];
}


private string[] translateFunction(in from!"clang".Cursor typedef_,
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

    const functionType = typedef_.underlyingType.canonical.kind == Type.Kind.Pointer
        ? typedef_.underlyingType.canonical.pointee
        : typedef_.underlyingType.canonical;

    const params = translateParamTypes(typedef_, functionType, context.indent).join(", ");
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
    newCursor.setSpelling(cursor.type.spelling);

    // delegate to whoever knows what they're doing
    return translate(newCursor, context);
}
