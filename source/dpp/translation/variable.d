module dpp.translation.variable;

import dpp.from;

string[] translateVariable(in from!"clang".Cursor cursor,
                           ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.VarDecl)
    do
{
    import dpp.translation.exception: UntranslatableException;
    import dpp.translation.dlang: maybePragma;
    import dpp.translation.translation: translateCursor = translate;
    import dpp.translation.type: translateType = translate;
    import dpp.translation.tokens: translateTokens;
    import clang: Cursor, Type, Token;
    import std.conv: text;
    import std.typecons: No;
    import std.algorithm: canFind, find, map;
    import std.array: empty, popFront, join, replace;

    string[] ret;

    const isAnonymous = cursor.type.spelling.canFind("(anonymous");
    // If the type is anonymous, then we need to define it before we declare
    // ourselves of that type, unless that type is an enum. See #54.
    if(isAnonymous && cursor.type.canonical.declaration.kind != Cursor.Kind.EnumDecl) {
        ret ~= translateCursor(cursor.type.canonical.declaration, context);
    }

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
    // e.g. enum foo = 42;
    const constexpr = cursor.tokens.canFind(Token(Token.Kind.Keyword, "constexpr"));

    if(constexpr)
        ret ~= translateConstexpr(spelling, cursor, context);
    else {
        const maybeTypeSpelling = translateType(cursor.type, context, No.translatingFunction);
        // In C it is possible to have an extern void variable
        const typeSpelling = cursor.type.kind == Type.Kind.Void
            ? maybeTypeSpelling.replace("void", "void*")
            : maybeTypeSpelling;
        ret ~=
            maybePragma(cursor, context) ~
            text("extern __gshared ", static_, typeSpelling, " ", spelling, ";");
    }

    return ret;
}


private string[] translateConstexpr(in string spelling,
                                    in from!"clang".Cursor cursor,
                                    ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.tokens: translateTokens;
    import dpp.translation.exception: UntranslatableException;
    import dpp.translation.type: translate;
    import clang: Cursor, Token;
    import std.algorithm: find, canFind;
    import std.conv: text;
    import std.array: empty, popFront;
    import std.typecons: No;

    auto tokens = cursor.tokens;
    tokens = tokens.find!(a => a.kind == Token.Kind.Punctuation && a.spelling == "=");

    const init = () {
        // see contract.constexpr.variable.init.braces
        if(cursor.children.canFind!(c => c.kind == Cursor.Kind.InitListExpr))
            return " = " ~ translate(cursor.type, context, No.translatingFunction) ~ ".init";

        if(!tokens.empty) {
            tokens.popFront;
            return " = " ~ translateTokens(tokens);
        }

        throw new UntranslatableException(
            text("Could not find assignment in ", cursor.tokens,
                 "\ncursor: ", cursor, "\n@ ", cursor.sourceRange));
    }();

    return [ text("enum ", spelling, init, ";") ];
}

private bool isRecordWithoutDefinition(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor, Type;

    const canonicalType = cursor.type.canonical;

    if(canonicalType.kind != Type.Kind.Record)
        return false;

    const declaration = canonicalType.declaration;
    const definition = declaration.definition;
    const specializedTemplate = declaration.specializedCursorTemplate;

    context.log("canonicalType: ", canonicalType);
    context.log("declaration: ", declaration);
    context.log("definition: ", definition);
    context.log("specialised cursor template: ", specializedTemplate);

    return
        definition.isInvalid &&
        // See #97
        specializedTemplate.kind != Cursor.Kind.ClassTemplate
        ;
}
