module dpp.translation.tokens;


import dpp.from;


string translateTokens(in from!"clang".Token[] tokens) @safe pure {
    import std.algorithm: map;
    import std.array: array, join;

    return tokens
        .translateSizeof
        .map!(a => a.spelling)
        .join;
}


// sizeof(foo) -> foo.sizeof
private auto translateSizeof(const(from!"clang".Token)[] tokens) @safe pure {
    import dpp.translation.type: translateString;
    import clang: Token;
    import std.algorithm: countUntil, map;
    import std.array: join, replace;

    for(;;) {
        const indexSizeof = tokens.countUntil!(a => a.kind == Token.Kind.Keyword && a.spelling == "sizeof");
        if(indexSizeof == -1) return tokens;
        const indexCloseParen = indexSizeof + tokens[indexSizeof..$].countUntil!(a => a.kind == Token.Kind.Punctuation && a.spelling == ")");
        const newTokenSpelling =
            "(" ~ tokens[indexSizeof + 2 .. indexCloseParen]
            .map!(a => a.spelling)
            .join(" ")
            ~ ").sizeof"
            ;

        tokens =
            tokens[0 .. indexSizeof] ~
            Token(Token.Kind.Literal, newTokenSpelling.translateString) ~
            tokens[indexCloseParen + 1 .. $];
    }
}
