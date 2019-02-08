/**
   Enum translation
 */
module dpp.translation.enum_;


import dpp.from;


string[] translateEnumConstant(in from!"dpp.ast.node".Node node,
                               ref from!"dpp.runtime.context".Context context)
    @safe
    in(node.kind == from!"clang".Cursor.Kind.EnumConstantDecl)
    do
{
    import dpp.translation.dlang: maybeRename;
    import std.conv: text;

    context.log("    Enum Constant Value: ", node.enumConstantValue);
    context.log("    tokens: ", node.tokens);

    return [text(maybeRename(node, context), ` = `, node.enumConstantValue, `, `)];
}
