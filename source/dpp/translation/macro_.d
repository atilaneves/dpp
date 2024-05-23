module dpp.translation.macro_;


import dpp.from;


string[] translateMacro(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.MacroDefinition)
{
    import dpp.translation.dlang: maybeRename;
    import clang: Cursor;
    import std.file: exists;
    import std.algorithm: startsWith;
    import std.conv: text;

    // we want non-built-in macro definitions to be defined and then preprocessed
    // again

    if(isBuiltinMacro(cursor)) return [];

    const tokens = cursor.tokens;

    // the only sane way for us to be able to see a macro definition
    // for a macro that has already been defined is if an #undef happened
    // in the meanwhile. Unfortunately, libclang has no way of passing
    // that information to us
    const maybeUndef = context.macroAlreadyDefined(cursor)
        ? "#undef " ~ cursor.spelling
        : "";

    context.rememberMacro(cursor);
    const spelling = maybeRename(cursor, context);
    const translation = translateToD(cursor, context, tokens);

    // We try here to make it so that literal macros can be imported from
    // another D module. We also try and make non-function-like macros
    // that aren't a literal constant but an expression can be imported
    // as well. To that end we check that we can mixin a declaration of
    // an enum with the same name of the macro with the original C code.
    // If so, we mix it in.
    // Below that, we declare the macro so the the #including .dpp file
    // uses the preprocessor.
    if(!cursor.isMacroFunction && tokens.length > 1) {
        string[] ret;
        const defineEnum = `enum ` ~ spelling ~ ` = ` ~ translation.dcode ~ `;`;
        if (translation.isLiteral)
        {
            // no need to have compiles checks with literals
            ret = [
                "    " ~ defineEnum,
            ];
        }
        else
        {
            if (translation.needsWrapperFunction)
            {
                ret = [
                    "    auto " ~ spelling ~ "()() @property {",
                    "        pragma(inline, true);",
                    "        return mixin(`"  ~ translation.dcode ~ "`);",
                    "    }",
                ];
            }
            else
            {
                const enumVarName = `enumMixinStr_` ~ spelling;
                ret = [
                    "    private enum " ~ enumVarName ~ " = `" ~ defineEnum ~ "`;",
                    `    static if(is(typeof({ mixin(` ~ enumVarName ~ `); }))) {`,
                    `        mixin(`  ~ enumVarName ~ `);`,
                    `    }`,
                ];
            }
        }
        return [
            `#ifdef ` ~ spelling,
            `#    undef ` ~ spelling,
            `#endif`,
            `static if(!is(typeof(` ~ spelling ~ `))) {`,
            ] ~ ret ~ [
            `}`,
            `#define ` ~ spelling ~ ` ` ~ translation.dcode,
        ];
    }

    // Define a template function with the same name as the macro
    // in an attempt to make it importable from outside the .dpp file.
    enum prefix = "_dpp_impl_"; // can't use the macro name as-is
    const emitFunction = cursor.isMacroFunction && context.options.functionMacros;
    auto maybeFunction = emitFunction
        ? macroToTemplateFunction(cursor, prefix, spelling)
        : [];
    const maybeSpace = cursor.isMacroFunction ? "" : " ";
    const restOfLine = spelling ~ maybeSpace ~ translation.dcode;
    const maybeDefineWithPrefix = emitFunction
        ? `#define ` ~ prefix ~ restOfLine
        : "";
    const define = `#define ` ~ restOfLine;

    return maybeUndef ~ maybeDefineWithPrefix ~ maybeFunction ~ define;
}

private string[] macroToTemplateFunction(in from!"clang".Cursor cursor, in string prefix, in string spelling)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.MacroDefinition)
    in(cursor.isMacroFunction)
{
    import clang : Token;
    import std.algorithm : countUntil, count, map, startsWith;
    import std.range: iota;
    import std.conv: text;
    import std.array : join;

    if(spelling.startsWith("__")) return [];

    const tokens = cursor.tokens;
    assert(tokens[0].kind == Token.Kind.Identifier);
    assert(tokens[1] == Token(Token.Kind.Punctuation, "("));

    const closeParenIndex = tokens[2 .. $].countUntil(Token(Token.Kind.Punctuation, ")")) + 2;
    const numCommas = tokens[2 .. closeParenIndex].count(Token(Token.Kind.Punctuation, ","));
    const numElements = closeParenIndex == 2 ? 0 : numCommas + 1;
    const isVariadic = tokens[closeParenIndex - 1] == Token(Token.Kind.Punctuation, "...");
    const numArgs = isVariadic ? numElements - 1 : numElements;
    const maybeVarTemplate = isVariadic ? ", REST..." : "";
    const templateParams = `(` ~ numArgs.iota.map!(i => text(`A`, i)).join(`, `) ~ maybeVarTemplate ~ `)`;
    const maybeVarParam = isVariadic ? ", REST rest" : "";
    const runtimeParams = `(` ~ numArgs.iota.map!(i => text(`A`, i, ` arg`, i)).join(`, `) ~ maybeVarParam ~ `)`;
    const maybeVarArg = isVariadic ? ", rest" : "";
    const runtimeArgs = numArgs.iota.map!(i => text(`arg`, i)).join(`, `) ~ maybeVarArg;
    auto lines = [
        `auto ` ~ spelling ~ templateParams ~ runtimeParams ~ ` {`,
        `    return ` ~ prefix ~ spelling ~ `(` ~ runtimeArgs ~ `);`,
        `}`,
    ];
    const functionMixinStr = lines.map!(l => "    " ~ l).join("\n");
    const enumName = prefix ~ spelling ~ `_mixin`;
    return [
        `enum ` ~ enumName ~ " = `" ~ functionMixinStr ~ "`;",
        `static if(__traits(compiles, { mixin(` ~  enumName ~ `); })) {`,
        `    mixin(` ~ enumName ~ `);`,
        `}`
    ];
}


bool isBuiltinMacro(in from!"clang".Cursor cursor)
    @safe
{
    import clang: Cursor;
    import std.file: exists;
    import std.algorithm: startsWith;

    if(cursor.kind != Cursor.Kind.MacroDefinition) return false;

    return
        cursor.sourceRange.path == ""
        || !cursor.sourceRange.path.exists
        || cursor.isPredefined
        || cursor.spelling.startsWith("__STDC_")
        ;
}


private bool isLiteralMacro(in from!"clang".Token[] tokens) @safe @nogc pure nothrow {
    import clang: Token;

    return
        tokens.length == 2
        && tokens[0].kind == Token.Kind.Identifier
        && tokens[1].kind == Token.Kind.Literal
        ;
}

private struct MacroTranslation
{
    string dcode;
    bool isLiteral;
    bool needsWrapperFunction;
}


private MacroTranslation translateToD(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    in from!"clang".Token[] tokens,
    )
    @safe
{
    import dpp.translation.type: translateElaborated;
    import clang: Token;
    import std.algorithm: map;

    if(isLiteralMacro(tokens)) return MacroTranslation(fixLiteral(tokens[1]), true);
    if(tokens.length == 1) return MacroTranslation.init; // e.g. `#define FOO`

    auto fixLiteralOrPassThrough(in Token t) {
        return t.kind == Token.Kind.Literal
            ? Token(Token.Kind.Literal, fixLiteral(t))
            : t;
    }

    return MacroTranslation(
        tokens
        .fixSizeof(cursor)
        .fixSelfCall(cursor, context)
        .translateGenericCastMacro
        .fixCasts(cursor, context)
        .fixArrow
        .fixNull
        .map!fixLiteralOrPassThrough
        .toString
        .translateElaborated(context),
        false,
        checkEnumNeedsWrapperFunction(cursor, context, tokens)
    );
}

private bool checkEnumNeedsWrapperFunction(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    in from!"clang".Token[] tokens,
    )
    @safe
{
    import std.algorithm : countUntil;
    import clang : Token;

    auto deref = tokens.countUntil!(a => a.isPunctuation("&"));
    if (deref != -1)
    {
        bool isPunctuationBefore = deref == 1 || tokens[deref - 1].kind == Token.Kind.Punctuation;
        bool isIdentifierAfter = tokens.length > deref + 1 && tokens[deref + 1].kind == Token.Kind.Identifier;
        if (isPunctuationBefore && isIdentifierAfter)
        {
            // probably taking address of something, wrap this in a property
            // function in case we try to access imported variables!

            // TODO: lookup symbol with identifier `tokens[deref + 1].spelling`
            // and only return true if it's `linkage == Linkage.External`
            return true;
        }
    }

    return false;
}


private string toString(R)(R tokens) {
    import clang: Token;
    import std.algorithm: map;
    import std.array: join;

    // skip the identifier because of DPP_ENUM_
    return tokens[1..$]
        .map!(t => t.spelling)
        .join(" ")
        ;

}

private string fixLiteral(in from!"clang".Token token)
    @safe pure
    in(token.kind == from!"clang".Token.Kind.Literal)
    do
{
    return token.spelling
        .fixLowercaseSuffix
        .fixMultiCharacterLiterals
        .fixWideCharStrings
        .fixOctal
        .fixMicrosoftSuffixes
        .fixLongLong
        ;
}


private auto fixArrow(R)(R tokens) {
    import clang: Token;
    import std.algorithm: map;

    static const(Token) replace(in Token token) {
        return token == Token(Token.Kind.Punctuation, "->")
            ? Token(Token.Kind.Punctuation, ".")
            : token;
    }

    return tokens
        .map!replace
        ;
}

private auto fixNull(R)(R tokens)
{
    import clang: Token;
    import std.algorithm: map;
    import std.array: array;

    static const(Token) replace(in Token token) {
        return token == Token(Token.Kind.Identifier, "NULL")
            ? Token(Token.Kind.Identifier, "null")
            : token;
    }

    return tokens
        .map!replace
        ;
}

private string fixMicrosoftSuffixes(in string str) @safe pure nothrow {
    import std.algorithm: endsWith;
    import std.string: representation;

    if(str.representation.endsWith("i64".representation, "I64".representation))
        return str[0 .. $-3] ~ "L";
    else if(str.representation.endsWith("i32".representation, "I32".representation))
        return str[0 .. $-3];
    else if(str.representation.endsWith("i16".representation, "I16".representation))
        return str[0 .. $-3];
    else if(str.representation.endsWith("i8".representation, "I8".representation))
        return str[0 .. $-2];
    return str;
}

private string fixWideCharStrings(in string str) @safe pure nothrow {
    if(str.length >=3 && str[0] == 'L' && str[1] == '"' && str[$-1] == '"') {
        return str[1 .. $] ~ "w";
    }

    return str;
}

private string fixMultiCharacterLiterals(in string str) @safe pure nothrow {
    // multi-character literals are implementation-defined, but allowed,
    // in C I aim to identify them and then distinguish them from a
    // non-ASCII character, which I'll just forward to D assuming utf-8 source
    // moreover, the '\uxxx' or other escape sequences should be forwarded
    if(str.length > 3 && str[0] == '\'' && str[$-1] == '\'' && str[1] != '\\') {
        // apparently a multi-char literal, let's translate to int
        // the way this is typically done in common compilers, e.g.
        // https://gcc.gnu.org/onlinedocs/cpp/Implementation-defined-behavior.html
        int result;
        foreach(char ch; str[1 .. $-1]) {
            // any multi-byte character I'm going to assume
            // is just a single UTF-8 char and punt on it.
            if(ch > 127) return str;
            result <<= 8;
            result |= cast(ubyte) ch;
        }
        import std.conv;
        return to!string(result);
    }
    return str; // not one of these, don't touch
}

private string fixLowercaseSuffix(in string str) @safe pure nothrow {
    import std.algorithm: endsWith;

    if(str.endsWith("ll"))
        return str[0 .. $-2] ~ "LL";
    if(str.endsWith("l"))
        return str[0 .. $-1] ~ "L";
    return str;
}

private string fixLongLong(in string str) @safe pure {
    import std.uni : toUpper;
    const suffix = str.length < 3 ? "" : str[$-3 .. $].toUpper;

    if (suffix.length > 0) {
        if (suffix == "LLU" || suffix == "ULL")
            return str[0 .. $-3] ~ "LU";

        if (suffix[1 .. $] == "LL")
            return str[0 .. $-2] ~ "L";
    }

    return str;
}


private string fixOctal(in string spelling) @safe pure {
    import clang: Token;
    import std.algorithm: countUntil;
    import std.uni: isNumber;
    import std.conv : text;

    const isOctal =
        spelling.length > 1
        && spelling[0] == '0'
        && spelling[1].isNumber
        ;

    if(!isOctal) return spelling;

    const firstNonZero = spelling.countUntil!(a => a != '0');
    if(firstNonZero == -1) return "0";

    const base8_representation = spelling[firstNonZero .. $];
    const base8_length = base8_representation.length;
    int base10_number = 0;
    foreach(i, c; base8_representation)
    {
        const power = base8_length - i - 1;
        const digit = c - '0';
        base10_number += digit * 8 ^^ power;
    }

    return "/+converted from octal '" ~ base8_representation ~ "'+/ " ~ base10_number.text;
}


private auto fixSizeof(R)(R tokens, in from !"clang".Cursor cursor)
{
    import clang: Token;
    import std.conv: text;
    import std.algorithm: countUntil;

    // find the closing paren for the function-like macro's argument list
    size_t lastIndex = 0;
    if(cursor.isMacroFunction) {
        lastIndex = tokens
            .countUntil!(t => t == Token(Token.Kind.Punctuation, ")"))
            +1; // skip the right paren

        if(lastIndex == 0)  // given the +1 above, -1 becomes 0
            throw new Exception(text("Can't fix sizeof in function-like macro with tokens: ", tokens));
    }

    const beginning = tokens[0 .. lastIndex];
    const(Token)[] middle;

    for(size_t i = lastIndex; i < tokens.length - 1; ++i) {
        if(tokens[i] == Token(Token.Kind.Keyword, "sizeof")
           && tokens[i + 1] == Token(Token.Kind.Punctuation, "("))
        {
            // find closing paren
            long open = 1;
            size_t scanIndex = i + 2;  // skip i + 1 since that's the open paren

            while(open != 0) {
                if(tokens[scanIndex] == Token(Token.Kind.Punctuation, "("))
                    ++open;
                if(tokens[scanIndex] == Token(Token.Kind.Punctuation, ")"))
                    --open;

                ++scanIndex;
            }

            middle ~= tokens[lastIndex .. i] ~ tokens[i + 1 .. scanIndex] ~ Token(Token.Kind.Keyword, ".sizeof");
            lastIndex = scanIndex;
            // advance i past the sizeof. -1 because of ++i in the for loop
            i = lastIndex - 1;
        }
    }

    // can't chain here due to fixCasts appending to const(Token)[]
    return beginning ~ middle ~ tokens[lastIndex .. $];
}


private auto fixSelfCall(
    const(from!"clang".Token)[] tokens,
    in from !"clang".Cursor cursor,
    in from!"dpp.runtime.context".Context context,
    )
{
    import clang : Token;
    import std.algorithm : any, map;
    import std.array : array;

    if (cursor.isMacroFunction && context.options.functionMacros)
    {
        auto macroName = cursor.spelling;
        if (tokens.any!(t => t == Token(Token.Kind.Identifier, macroName)))
        {
            string renamedName = macroName ~ "_";
            return tokens.map!(t =>
                t == Token(Token.Kind.Identifier, macroName)
                    ? Token(Token.Kind.Identifier, renamedName)
                    : t).array;
        }
    }
    return tokens;
}

private auto fixCasts(R)(
    R tokens,
    in from !"clang".Cursor cursor,
    in from!"dpp.runtime.context".Context context,
    )
{
    import dpp.translation.exception: UntranslatableException;
    import dpp.translation.type : translateString;
    import clang: Token;
    import std.conv: text;
    import std.algorithm: countUntil, count, canFind, all, map;
    import std.range: chain;
    import std.array: split, join;

    // If the cursor is a macro function return its parameters
    Token[] macroFunctionParams() {
        import std.conv: text;
        assert(cursor.tokens[0].kind == Token.Kind.Identifier || cursor.tokens[0].kind == Token.Kind.Keyword,
               cursor.tokens[0].kind.text);
        assert(cursor.tokens[1] == Token(Token.Kind.Punctuation, "("));
        enum fromParen = 2;
        const closeParenIndex = cursor.tokens[fromParen .. $].countUntil(Token(Token.Kind.Punctuation, ")")) + fromParen;
        return cursor.tokens[fromParen .. closeParenIndex].split(Token(Token.Kind.Punctuation, ",")).join;
    }

    const params = cursor.isMacroFunction ? macroFunctionParams : [];

    // if the token array is a built-in or user-defined type
    bool isType(in Token[] tokens) {

        if( // fundamental type
            tokens.length == 1
            && tokens[0].kind == Token.Kind.Keyword
            && tokens[0].spelling != "sizeof"
            && tokens[0].spelling != "alignof"
            )
            return true;

        // fundamental type like `unsigned char`
        if(tokens.length > 1 && tokens.all!(t => t.kind == Token.Kind.Keyword))
            return true;

        if( // user defined type
            tokens.length == 1
            && tokens[0].kind == Token.Kind.Identifier
            && context.isUserDefinedType(tokens[0].spelling)
            )
            return true;

        if(  // pointer to a type
            tokens.length >= 2
            && tokens[$-1] == Token(Token.Kind.Punctuation, "*")
            && (isType(tokens[0 .. $-1]) || params.canFind(tokens[$-2]) )
            )
            return true;

        if( // const type
            tokens.length >= 2
            && tokens[0] == Token(Token.Kind.Keyword, "const")
            && isType(tokens[1..$])
            )
            return true;

        if( // typeof
            tokens.length >= 2
            && tokens[0] == Token(Token.Kind.Keyword, "typeof")
            )
            return true;

        if ( // macro attribute (e.g. __force) + type
            tokens.length >= 2
            && tokens[0].kind == Token.Kind.Identifier
            && isType(tokens[1..$])
            )
            return true;

        return false;
    }

    size_t lastIndex = 0;
    // find the closing paren for the function-like macro's argument list
    if(cursor.isMacroFunction) {
        lastIndex = tokens
            .countUntil!(t => t.isPunctuation(")"))
            +1; // skip the right paren
        if(lastIndex == 0)
            throw new Exception(text("Can't fix casts in function-like macro with tokens: ", tokens));
    }

    const beginning = tokens[0 .. lastIndex];
    const(Token)[] middle;

    // See #244 - macros can have unbalanced parentheses
    const numLeftParens  = tokens.count!(a => a.isPunctuation("(") ||
                                        // `cast(` is generated by translateGenericCastMacro
                                        a.isPunctuation("cast("));
    const numRightParens = tokens.count!(a => a.isPunctuation(")"));

    if(numLeftParens != numRightParens)
        throw new UntranslatableException("Unbalanced parentheses in macro `" ~ cursor.spelling ~ "`");

    for(size_t i = lastIndex; i < tokens.length - 1; ++i) {
        if(tokens[i].isPunctuation("(")) {
            auto closingParen = findMatchingParentheses(tokens, i);
            assert(closingParen != -1, "shouldn't panic with balanced parens");

            // we want to ignore e.g. `(int)(foo).sizeof` even if `foo` is a type
            const followedByDot =
                closingParen + 1 < tokens.length
                && tokens[closingParen + 1].spelling[0] == '.'
                ;

            if(isType(tokens[i + 1 .. closingParen]) && !followedByDot) {
                // -1 to not include the closing paren
                const cTypeString = tokens[i + 1 .. closingParen].map!(t => t.spelling).join(" ");
                const dTypeString = translateString(cTypeString, context);
                middle ~= tokens[lastIndex .. i] ~
                    Token(Token.Kind.Punctuation, "cast(") ~
                    Token(Token.Kind.Keyword, dTypeString) ~
                    Token(Token.Kind.Punctuation, ")");

                lastIndex = closingParen + 1;
                // advance i past the sizeof. -1 because of ++i in the for loop
                i = lastIndex - 1;
            }
        }
    }

    return chain(beginning, middle, tokens[lastIndex .. $]);
}

/// Attempts to convert a small subset of probably-cast macros to D casts.
///
/// Example of a translation this does:
///
/// ---
/// MACRONAME ( type , expr ) ( ( type ) ( expr ) )
/// ->
/// MACRONAME ( type , expr ) ( cast( type ) ( expr ) )
/// ---
private auto translateGenericCastMacro(in from!"clang".Token[] tokens) @safe
{
    import clang : Token;
    import std.algorithm : canFind;

    // special case when macro is `((identifier)(...))` or `(identifier)(...)`
    // and `identifier` is a parameter, we assume it's a cast to `identifier`
    // otherwise it could be a call to a function (pointer), but we just hope
    // this is not the case here

    if (!tokens[1].isPunctuation("("))
        return tokens;

    auto macroArgsEnd = findMatchingParentheses(tokens, 1);
    if (macroArgsEnd == -1 || macroArgsEnd + 1 >= tokens.length)
        return tokens;

    if (!tokens[macroArgsEnd + 1].isPunctuation("("))
        return tokens;

    auto macroArgs = tokens[2 .. macroArgsEnd];
    auto macroDefinition = tokens[macroArgsEnd + 1 .. $];
    size_t castLocation = 0;

    if (macroDefinition.length > 2
        && macroDefinition[0].isPunctuation("(")
        && macroDefinition[$ - 1].isPunctuation(")"))
    {
        // everything wrapped in parentheses `(...)`, unwrap once to resolve
        castLocation = 1;
    }

    if (castLocation + 3 < macroDefinition.length
        && macroDefinition[castLocation].isPunctuation("(")
        && macroDefinition[castLocation + 1].kind == Token.Kind.Identifier
        && macroDefinition[castLocation + 2].isPunctuation(")")
        && macroDefinition[castLocation + 3].isPunctuation("(")
        && macroArgs.canFind(macroDefinition[castLocation + 1]))
    {
        // looks like this is probably a cast, make it a D cast
        auto sourceIndex = macroArgsEnd + 1 + castLocation + 1;
        assert(&macroDefinition[castLocation + 1] is &tokens[sourceIndex]);
        return tokens[0 .. sourceIndex - 1]
            ~ Token(Token.Kind.Punctuation, "cast(")
            ~ tokens[sourceIndex .. $];
    }

    return tokens;
}

/// Returns: `token index` for the matching closing parentheses. If no
/// matching closing parentheses is found, `-1` is returned.
private ptrdiff_t findMatchingParentheses(
    const(from!"clang".Token)[] tokens,
    ptrdiff_t i
    )
    @safe
in (tokens[i].isPunctuation("("))
out (r; r == -1
    || tokens[r].isPunctuation(")")) //" quote is just here to unconfuse my syntax highlighter
{
    int depth = 1;
    while (depth != 0) {
        ++i;
        if (i >= tokens.length)
            break;
        if(tokens[i].isPunctuation("("))
            ++depth;
        if(tokens[i].isPunctuation(")"))
            --depth;
    }

    if (i >= tokens.length)
        return -1;
    return i;
}

///
@("findMatchingParentheses")
@safe unittest
{
    import unit_threaded: shouldEqual;
    import clang : Token;

    auto tokens = [
        /* 0 */ Token(Token.Kind.Identifier, "myFunc"),
        /* 1 */ Token(Token.Kind.Punctuation, "("),
        /* 2 */ Token(Token.Kind.Identifier, "a"),
        /* 3 */ Token(Token.Kind.Punctuation, "("),
        /* 4 */ Token(Token.Kind.Identifier, "b"),
        /* 5 */ Token(Token.Kind.Punctuation, ")"),
        /* 6 */ Token(Token.Kind.Punctuation, ","),
        /* 7 */ Token(Token.Kind.Identifier, "c"),
        /* 8 */ Token(Token.Kind.Punctuation, ")"),
        /* 9 */ Token(Token.Kind.Punctuation, ";"),
    ];

    findMatchingParentheses(tokens, 1).shouldEqual(8);
    findMatchingParentheses(tokens, 3).shouldEqual(5);
    findMatchingParentheses(tokens[0 .. 6], 1).shouldEqual(-1);
    findMatchingParentheses(tokens[0 .. 6], 3).shouldEqual(5);
}

private bool isPunctuation(const from!"clang".Token token, string expected) @safe
{
    // Apparently libclang sometimes tokenises `\\n)` as including the backslash and the newline

    import clang : Token;
    import std.string : replace, strip;

    return token.kind == Token.Kind.Punctuation
        && token.spelling.replace("\r", "\n").replace("\\\n", "").strip == expected;
}

///
@("isPunctuation")
@safe unittest
{
    import clang : Token;

    assert(Token(Token.Kind.Punctuation, "(").isPunctuation("("));
    assert(!Token(Token.Kind.Punctuation, "(").isPunctuation(")"));
    assert(Token(Token.Kind.Punctuation, "(\\\n ").isPunctuation("("));
    assert(Token(Token.Kind.Punctuation, "\t\\\n  )").isPunctuation(")"));
    assert(!Token(Token.Kind.Punctuation, "\t\\\n  )").isPunctuation("("));
}
