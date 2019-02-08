/**
   Enum translation
 */
module dpp.translation.enum_;


import dpp.from;


string[] translateEnumConstant(in from!"dpp.ast.node".Node node,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.dlang: maybeRename;
    import clang: Cursor;
    import std.conv: text;

    assert(node.kind == Cursor.Kind.EnumConstantDecl);
    context.log("    Enum Constant Value: ", node.enumConstantValue);
    context.log("    tokens: ", node.tokens);
    return [maybeRename(node, context) ~ ` = ` ~ text(node.enumConstantValue) ~ `, `];
}
