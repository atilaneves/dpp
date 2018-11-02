module dpp.translation.tokens;


import dpp.from;


string translateTokens(in from!"clang".Token[] tokens) @safe pure {
    import dpp.translation.type: translateString;
    import std.algorithm: map;
    import std.array: array, join;

    return tokens
        .translateProperty("sizeof")
        .translateProperty("alignof")
        .map!(a => a.spelling.translateString)
        .join;
}


// sizeof(foo) -> foo.sizeof, alignof(foo) -> foo.alignof
private auto translateProperty(const(from!"clang".Token)[] tokens, in string property) @safe pure {
    import dpp.translation.type: translateString;
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
            Token(Token.Kind.Literal, newTokenSpelling.translateString) ~
            tokens[indexCloseParen + 1 .. $];
    }
}
