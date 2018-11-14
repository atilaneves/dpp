module dpp2.translation.translation;


import dpp.from;


string[] translate(from!"dpp2.sea.node".Node node)
    @safe pure
{
    import dpp2.sea.node;
    import sumtype: match;

    return node.match!(
        translateStruct,
    );
}


string[] translateStruct(in from!"dpp2.sea.node".Struct struct_)
    @safe pure
{
    import dpp2.translation.type: translate;
    import std.algorithm: map;
    import std.array: array;

    string[] lines;

    lines ~= "struct " ~ struct_.spelling;
    lines ~= "{";

    lines ~= struct_
        .fields
        .map!(f => translate(f.type) ~ " " ~ f.spelling ~ ";")
        .array
        ;

    lines ~= "}";

    return lines;
}
