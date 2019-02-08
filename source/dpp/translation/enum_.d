/**
   Enum translation
 */
module dpp.translation.enum_;


import dpp.from;


string[] translateEnumConstant(in string spelling,
                               in from!"dpp.ast.node".EnumMember enumMember,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.dlang: maybeRename;
    import std.conv: text;

    context.log("    Enum Constant Value: ", enumMember.value);

    return [text(maybeRename(spelling, context), ` = `, enumMember.value, `, `)];
}
