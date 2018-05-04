module dpp.cursor.variable;

import dpp.from;

string[] translateVariable(in from!"clang".Cursor cursor,
                           ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.cursor.dlang: maybePragma;
    import dpp.cursor.translation: translateCursor = translate;
    import dpp.type: translateType = translate;
    import clang: Cursor, Type;
    import std.conv: text;
    import std.typecons: No;
    import std.algorithm: canFind;

    assert(cursor.kind == Cursor.Kind.VarDecl);

    string[] ret;

    const isAnonymous = cursor.type.spelling.canFind("(anonymous");
    // If the type is anonymous, then we need to define it before we declare
    // ourselves of that type.
    if(isAnonymous) ret ~= translateCursor(cursor.type.canonical.declaration, context);

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

    const spelling = context.rememberLinkable(cursor);

    // global variable or static member of a struct/class?
    const static_ = cursor.semanticParent.type.canonical.kind == Type.Kind.Record
        ? "static  "
        : "";

    ret ~=
        maybePragma(cursor, context) ~
        text("extern __gshared ", static_,
             translateType(cursor.type, context, No.translatingFunction), " ", spelling, ";")
    ;

    return ret;
}


private bool isRecordWithoutDefinition(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context)
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
