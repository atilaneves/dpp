module include.translation.typedef_;

import include.from;

string[] translateTypedef(in from!"clang".Cursor typedef_,
                          in from!"include.runtime.options".Options options =
                                 from!"include.runtime.options".Options())
    @safe
{
    import include.translation.aggregate: spellingOrNickname;
    import include.translation.type: cleanType, translate;
    import clang: Type;
    import std.conv: text;
    version(unittest) import unit_threaded.io: writelnUt;

    version(unittest)
        writelnUt("    TypedefDecl children: ", typedef_.children);

    assert(typedef_.children.length == 1 ||
           (typedef_.children.length == 0 && typedef_.type.kind == Type.Kind.Typedef),
           text("typedefs should only have 1 member, not ", typedef_.children.length));

    version(unittest) writelnUt("    Underlying type: ", typedef_.underlyingType);

    const originalSpelling = typedef_.children.length
        ? spellingOrNickname(typedef_.children[0])
        : translate(typedef_.underlyingType, options);

    return [`alias ` ~ typedef_.spelling ~ ` = ` ~ originalSpelling.cleanType  ~ `;`];
}
