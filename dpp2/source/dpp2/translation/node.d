module dpp2.translation.node;


import dpp.from;


// FIXME - all of the parameters should be const but `match` won't have it


string[] translate(from!"dpp2.sea.node".Node node)
    @safe pure
{
    import dpp2.sea.node;
    import sumtype: match;

    return node.match!(
        translateStruct,
        translateField,
    );
}


string[] translateStruct(from!"dpp2.sea.node".Struct struct_)
    @safe pure
{
    import dpp2.sea.node: Node;
    import std.algorithm: map;
    import std.array: array, join;

    string[] lines;

    lines ~= "struct " ~ struct_.spelling;
    lines ~= "{";

    lines ~= struct_
        .nodes
        .map!translate
        .join
        ;

    lines ~= "}";

    return lines;
}


string[] translateField(from!"dpp2.sea.node".Field field)
    @safe pure
{
    import dpp2.translation.type: translate;
    return ["    " ~ translate(field.type) ~ " " ~ field.spelling ~ ";"];
}
