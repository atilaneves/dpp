module dpp2.translation.node;


import dpp.from;


string[] translate(in from!"dpp2.sea.node".Node[] nodes) {
    import std.algorithm: map;
    import std.array: join;
    return nodes.map!translate.join;
}


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

    const spelling = struct_.spelling == ""
        ? struct_.typeSpelling
        : struct_.spelling;

    lines ~= "struct " ~ spelling;
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
    import dpp2.translation.type: translate;
    const underlyingTranslation = translate(typedef_.underlying);
    return typedef_.spelling == underlyingTranslation
        ? []
        : ["alias " ~ typedef_.spelling ~ " = " ~  underlyingTranslation ~ ";"];
}
