module dpp2.translation.node;


import dpp.from;


string[] translate(in from!"dpp2.sea.node".Node node)
    @safe pure
{
    import dpp2.sea.node;
    import sumtype: match;

    return node.match!(
        translateStruct,
        translateField,
        translateTypedef,
    );
}


string[] translateStruct(in from!"dpp2.sea.node".Struct struct_)
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


string[] translateField(in from!"dpp2.sea.node".Field field)
    @safe pure
{
    import dpp2.translation.type: translate;
    return ["    " ~ translate(field.type) ~ " " ~ field.spelling ~ ";"];
}


string[] translateTypedef(in from!"dpp2.sea.node".Typedef typedef_)
    @safe pure
{
    return ["alias " ~ typedef_.spelling ~ " = " ~ typedef_.underlying ~ ";"];
}
