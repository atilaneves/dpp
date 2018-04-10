/**
   Function translations.
 */
module dpp.cursor.function_;

import dpp.from;

string[] translateFunction(in from!"clang".Cursor cursor,
                           ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.cursor.dlang: maybeRename, maybePragma;
    import dpp.type: translate;
    import clang: Cursor, Language;
    import std.array: join, array;
    import std.conv: text;
    import std.algorithm: endsWith;
    import std.typecons: Yes;

    assert(cursor.kind == Cursor.Kind.FunctionDecl);

    const indentation = context.indentation;
    context.log("Function return type (raw):        ", cursor.returnType);
    const returnType = translate(cursor.returnType, context, Yes.translatingFunction);
    context.setIndentation(indentation);
    context.log("Function return type (translated): ", returnType);

    () @trusted { maybeRememberStructs(paramTypes(cursor).array, context); }();

    // Here we used to check that if there were no parameters and the language is C,
    // then the correct translation in D would be (...);
    // However, that's not allowed in D. It just so happens that C production code
    // exists that doesn't bother with (void), so instead of producing something that
    // doesn't compile, we compromise and assume the user meant (void)

    const paramTypes = translateParamTypes(cursor, context).array;
    const isVariadic = cursor.type.spelling.endsWith("...)");
    const variadicParams = isVariadic ? "..." : "";
    const allParams = paramTypes ~ variadicParams;

    const spelling = context.rememberLinkable(cursor);

    return [
        maybePragma(cursor, context) ~
        text(returnType, " ", spelling, "(", allParams.join(", "), ");")
    ];
}

auto translateParamTypes(in from!"clang".Cursor cursor,
                         ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.type: translate;
    import std.algorithm: map;
    import std.range: tee;
    import std.typecons: Yes;

    return paramTypes(cursor)
        .tee!((a){ context.log("Function Child: ", a); })
        .map!(a => translate(a, context, Yes.translatingFunction))
        ;
}

auto paramTypes(in from!"clang".Cursor cursor)
    @safe
{
    import clang: Cursor;
    import std.algorithm: map, filter;

    return cursor
        .children
        .filter!(a => a.kind == Cursor.Kind.ParmDecl)
        .map!(a => a.type)
        ;
}



private void maybeRememberStructs(in from!"clang".Type[] types,
                                  ref from!"dpp.runtime.context".Context context)
    @safe pure
{
    import dpp.type: translate;
    import clang: Type;
    import std.algorithm: map, filter;

    auto structTypes = types
        .filter!(a => a.kind == Type.Kind.Pointer && a.pointee.canonical.kind == Type.Kind.Record)
        .map!(a => a.pointee.canonical);

    void rememberStruct(in Type pointeeCanonicalType) {
        const translatedType = translate(pointeeCanonicalType, context);
        // const becomes a problem if we have to define a struct at the end of all translations.
        // See it.compile.projects.nv_alloc_ops
        enum constPrefix = "const(";
        const cleanedType = pointeeCanonicalType.isConstQualified
            ? translatedType[constPrefix.length .. $-1] // unpack from const(T)
            : translatedType;

        if(cleanedType != "va_list")
            context.rememberFieldStruct(cleanedType);
    }

    foreach(structType; structTypes)
        rememberStruct(structType);
}
