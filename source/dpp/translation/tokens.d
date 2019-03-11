module dpp.translation.tokens;


import dpp.from;


string translateTokens(in from!"clang".Token[] tokens) @safe {
    import dpp.translation.type: translateString;
    import dpp.runtime.context: Context;
    import clang: Token;
    import std.algorithm: map, filter, canFind, endsWith;
    import std.array: array, join, replace;

    const translatedPropertyTokens = tokens
        .translateProperty("sizeof")
        .translateProperty("alignof")
        ;

    // we can't rely on `translateString` for angle brackets here since it
    // checks if there are matching pairs in the string to translate.
    // Since we have an array of tokens, the matching pair might be in a different position

    const canFindOpeningAngle = translatedPropertyTokens
        .canFind!(t => t.kind == Token.Kind.Punctuation && t.spelling == "<");
    const canFindClosingAngle = translatedPropertyTokens
        .canFind!(t => t.kind == Token.Kind.Punctuation && (t.spelling == ">" || t.spelling == ">>"));

    const translatedAngleBracketTokens = canFindOpeningAngle && canFindClosingAngle
        ? translatedPropertyTokens
            .map!(t => Token(t.kind, t.spelling.replace("<", "!(").replace(">>", "))").replace(">", ")")))
            .array
        : translatedPropertyTokens;

    auto ret = translatedAngleBracketTokens
        .filter!(t => t.kind != Token.Kind.Keyword || t.spelling != "typename")
        .map!(t => translateString(t.spelling, Context()))
        .join;

    // this can happen because of ending with ">>"
    if(ret.endsWith("))")) ret = ret[0 .. $-1];

    return ret;
}


// sizeof(foo) -> foo.sizeof, alignof(foo) -> foo.alignof
private auto translateProperty(const(from!"clang".Token)[] tokens, in string property) @safe {
    import dpp.translation.type: translateString;
    import dpp.runtime.context: Context;
    import clang: Token;
    import std.algorithm: countUntil, map;
    import std.array: join, replace;

    for(;;) {
        const indexProperty = tokens.countUntil!(a => a.kind == Token.Kind.Keyword && a.spelling == property);
        if(indexProperty == -1) return tokens;
        const indexCloseParen = indexProperty + tokens[indexProperty..$].countUntil!(a => a.kind == Token.Kind.Punctuation && a.spelling == ")");
        const newTokenSpelling =
            "(" ~ tokens[indexProperty + 2 .. indexCloseParen]
            .map!(a => a.spelling)
            .join(" ")
            ~ ")." ~ property
            ;

        tokens =
            tokens[0 .. indexProperty] ~
            Token(Token.Kind.Literal, translateString(newTokenSpelling, Context())) ~
            tokens[indexCloseParen + 1 .. $];
    }
}
