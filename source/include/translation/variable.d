module include.translation.variable;

import include.from;

string[] translateVariable(in from!"clang".Cursor cursor,
                           ref from!"include.runtime.context".Context context)
    @safe
{
    import include.type: translate;
    import clang: Cursor;
    import std.conv: text;
    import std.typecons: No;

    assert(cursor.kind == Cursor.Kind.VarDecl);

    // variables can be declared multiple times in C but only one in D
    if(!cursor.isCanonical) return [];

    // Don't bother if we don't have a definition anywhere - C allows this but D
    // doesn't. See it.compile.projects.ASN1_ITEM or try #including <openssl/ssl.h>.
    // There will be a problem with the global variables such as DHparams_it that
    // have a struct with an unknown type unless one includes <openssl/asn1t.h>
    // as well. In C, as long as one doesn't try to do anything with the variable,
    // that's ok. In D, it's not. Essentially:
    // struct Foo;
    // extern Foo gFoo;
    if(isRecordWithoutDefinition(cursor, context)) return [];

    return [text("extern __gshared ",
                 translate(cursor.type, context, No.translatingFunction), " ", cursor.spelling, ";")];
}


private bool isRecordWithoutDefinition(
    in from!"clang".Cursor cursor,
    ref from!"include.runtime.context".Context context)
    @safe
{
    import clang: Type;

    const canonicalType = cursor.type.canonical;

    if(canonicalType.kind != Type.Kind.Record)
        return false;


    const declaration = canonicalType.declaration;
    const definition = declaration.definition;

    context.log("canonicalType: ", canonicalType);
    context.log("declaration: ", declaration);
    context.log("definition: ", definition);

    return definition.isInvalid;
}
