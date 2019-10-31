/**
   Function translations.
 */
module dpp.translation.function_;

import dpp.from;


enum OPERATOR_PREFIX = "operator";


string[] translateFunction(in from!"clang".Cursor cursor,
                           ref from!"dpp.runtime.context".Context context)
    @safe
    in(
        cursor.kind == from!"clang".Cursor.Kind.FunctionDecl ||
        cursor.kind == from!"clang".Cursor.Kind.CXXMethod ||
        cursor.kind == from!"clang".Cursor.Kind.Constructor ||
        cursor.kind == from!"clang".Cursor.Kind.Destructor ||
        cursor.kind == from!"clang".Cursor.Kind.ConversionFunction ||
        cursor.kind == from!"clang".Cursor.Kind.FunctionTemplate
    )
    do
{
    import dpp.translation.dlang: maybePragma;
    import dpp.translation.aggregate: maybeRememberStructs;

    if(ignoreFunction(cursor)) return [];

    // FIXME - stop special casing the move ctor
    auto moveCtorLines = maybeMoveCtor(cursor, context);
    if(moveCtorLines.length) return moveCtorLines;

    string[] lines;

    // FIXME: this breaks with dmd 2.086.0 due to D's copy ctor
    //lines ~= maybeCopyCtor(cursor, context);
    lines ~= maybeOperator(cursor, context);

    // never declared types might lurk here
    maybeRememberStructs(cursor.type.paramTypes, context);

    const spelling = functionSpelling(cursor, context);

    lines ~= [
        maybePragma(cursor, context) ~ functionDecl(cursor, context, spelling)
    ];

    context.log("");

    return lines;
}

private bool ignoreFunction(in from!"clang".Cursor cursor) @safe {
    import dpp.translation.aggregate: dKeywordFromStrass;
    import clang: Cursor, Type, Token;
    import std.algorithm: countUntil, any, canFind, startsWith;

    // C++ partial specialisation function bodies
    if(cursor.semanticParent.kind == Cursor.Kind.ClassTemplatePartialSpecialization)
        return true;

    const tokens = cursor.tokens;

    // C++ deleted functions
    const deleteIndex = tokens.countUntil(Token(Token.Kind.Keyword, "delete"));
    if(deleteIndex != -1 && deleteIndex > 1) {
        if(tokens[deleteIndex - 1] == Token(Token.Kind.Punctuation, "="))
            return true;
    }

    // C++ member functions defined "outside the class", e.g.
    // `int Foo::bar() const { return 42; }`
    // This first condition checks if the function cursor has a body (compound statement)
    if(cursor.children.any!(a => a.kind == Cursor.Kind.CompoundStmt)) {

        // If it has a body, we check that its tokens contain "::" in the right place

        const doubleColonIndex = tokens.countUntil(Token(Token.Kind.Punctuation, "::"));

        if(doubleColonIndex != -1) {
            const nextToken = tokens[doubleColonIndex + 1];
            // The reason we're not checking the next token's spelling exactly is
            // because for templated types the cursor's spelling might be `Foo<T>`
            // but the token is `Foo`.
            if(nextToken.kind == Token.Kind.Identifier &&
               cursor.spelling.startsWith(nextToken.spelling))
                return true;
        }
    }

    // No default contructors for structs in D
    if(
        cursor.kind == Cursor.Kind.Constructor
        && numParams(cursor) == 0
        && dKeywordFromStrass(cursor.semanticParent) == "struct"
    )
        return true;

    // Ignore C++ methods definitions outside of the class
    // The lexical parent only differs from the semantic parent
    // in this case.
    if(
        // the constructor type is for issue 115 test on Windows.
        // it didn't trigger the check above because the CompoundStmts
        // are not present on the Windows builds of libclang for
        // template member functions (reason unknown)
        // but this check appears to do the right thing anyway.
        (cursor.kind == Cursor.Kind.CXXMethod || cursor.kind == Cursor.Kind.Constructor)
        && cursor.semanticParent != cursor.lexicalParent
    )
        return true;

    return false;
}

private string functionDecl(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    in string spelling,
    in from!"std.typecons".Flag!"names" names = from!"std.typecons".No.names
)
    @safe
{
    import dpp.translation.template_: translateTemplateParams;
    import dpp.translation.exception: UntranslatableException;
    import dpp.clang: isOverride, isFinal;
    import std.conv: text;
    import std.algorithm: endsWith, canFind;
    import std.array: join;

    context.log("Function return type (raw):        ", cursor.type.returnType);
    context.log("Function children: ", cursor.children);
    context.log("Function paramTypes: ", cursor.type.paramTypes);
    const returnType = returnType(cursor, context);
    context.log("Function return type (translated): ", returnType);

    const params = translateAllParamTypes(cursor, context, names).join(", ");
    context.log("Translated parameters: '", params, "'");
    // const C++ method?
    const const_ = cursor.isConstCppMethod ? " const" : "";

    auto templateParams = translateTemplateParams(cursor, context);
    const ctParams = templateParams.empty
        ? ""
        : "(" ~ templateParams.join(", ") ~ ")"
        ;

    // FIXME: avoid opBinary(string op: )(CT params)(RT params)
    // See it.cpp.function_.opBinary
    if(ctParams != "" && spelling.canFind("("))
        throw new UntranslatableException("BUG with templated operators");

    string prefix() {
        import dpp.translation.aggregate: dKeywordFromStrass;

        if(cursor.semanticParent.dKeywordFromStrass == "struct")
            return "";

        if(cursor.isPureVirtual)
            return "abstract ";

        if(!cursor.isVirtual)
            return "final ";

        // If we get here it's a virtual member function.
        // We might need to add D `final` and/or `override`.
        string ret;

        if(cursor.isOverride) ret ~= "override ";
        if(cursor.isFinal) ret ~= "final ";

        return ret;
    }

    return text(prefix, returnType, " ", spelling, ctParams, "(", params, ") @nogc nothrow", const_, ";");
}

private string returnType(in from!"clang".Cursor cursor,
                          ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.type: translate;
    import clang: Cursor;
    import std.typecons: Yes;

    const blob = blob(cursor.returnType, context);
    if(blob != "") return blob;

    const indentation = context.indentation;

    const isCtorOrDtor = isConstructor(cursor) || cursor.kind == Cursor.Kind.Destructor;
    const dType = isCtorOrDtor
        ? ""
        : translate(cursor.returnType, context, Yes.translatingFunction);

    context.setIndentation(indentation);

    const maybeStatic = cursor.storageClass == Cursor.StorageClass.Static ? "static " : "";

    return maybeStatic ~ dType;
}

private string[] maybeOperator(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{
    import std.algorithm: map;
    import std.array: join, array;
    import std.typecons: Yes;
    import std.range: iota;
    import std.conv: text;

    if(!isSupportedOperatorInD(cursor)) return [];

    const params = translateAllParamTypes(cursor, context).array;

    return [
        // remove semicolon from the end with [0..$-1]
        `extern(D) ` ~ functionDecl(cursor, context, operatorSpellingD(cursor, context), Yes.names)[0..$-1],
        `{`,
        `    return ` ~ operatorSpellingCpp(cursor, context) ~ `(` ~ params.length.iota.map!(a => text("arg", a)).join(", ") ~ `);`,
        `}`,
    ];
}

private bool isSupportedOperatorInD(in from!"clang".Cursor cursor) @safe nothrow {
    import dpp.translation.aggregate: dKeywordFromStrass;
    import clang: Cursor;
    import std.algorithm: map, canFind;

    if(!isOperator(cursor)) return false;

    // No D support for free function operator overloads
    if(cursor.semanticParent.kind == Cursor.Kind.TranslationUnit) return false;

    const cppOperator = cursor.spelling[OPERATOR_PREFIX.length .. $];

    // FIXME - should only check for identity assignment,
    // not all assignment operators
    if(dKeywordFromStrass(cursor.semanticParent) == "class" && cppOperator == "=")
        return false;

    const unsupportedSpellings = [`!`, `,`, `&&`, `||`, `->`, `->*`];
    if(unsupportedSpellings.canFind(cppOperator)) return false;

    if(isUnaryOperator(cursor) && cppOperator == "&") return false;
    if(!isUnaryOperator(cursor) && !isBinaryOperator(cursor)) return false;

     return true;
}

private bool isOperator(in from!"clang".Cursor cursor) @safe pure nothrow {
    import std.algorithm: startsWith;
    return
        cursor.spelling.startsWith(OPERATOR_PREFIX)
        && cursor.spelling.length > OPERATOR_PREFIX.length
        && cursor.spelling[OPERATOR_PREFIX.length] != '_'
        ;
}


private string functionSpelling(in from!"clang".Cursor cursor,
                                ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;

    if(isConstructor(cursor)) return "this";
    if(cursor.kind == Cursor.Kind.Destructor) return "~this";

    if(isOperator(cursor)) return operatorSpellingCpp(cursor, context);

    // if no special case
    return context.rememberLinkable(cursor);
}

private bool isConstructor(in from!"clang".Cursor cursor) @safe nothrow {
    import clang: Cursor;
    import std.algorithm: startsWith;

    return cursor.kind == Cursor.Kind.Constructor ||
        cursor.spelling.startsWith(cursor.semanticParent.spelling ~ "<");
}

private string operatorSpellingD(in from!"clang".Cursor cursor,
                                 ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.range: walkLength;
    import std.algorithm: canFind;
    import std.conv: text;

    const cppOperator = cursor.spelling[OPERATOR_PREFIX.length .. $];

    if(cursor.kind == Cursor.Kind.ConversionFunction) {
        return `opCast(T: ` ~ returnType(cursor, context) ~ `)`;
    }

    if(cppOperator.length > 1 &&
       cppOperator[$-1] == '=' &&
       (cppOperator.length != 2 || !['=', '!', '<', '>'].canFind(cppOperator[0])))
        return `opOpAssign(string op: "` ~ cppOperator[0 .. $-1] ~ `")`;

    assert(isUnaryOperator(cursor) || isBinaryOperator(cursor),
           text("Cursor is neither a unary or binary operator: ", cursor, "@", cursor.sourceRange.start));
    const dFunction = isBinaryOperator(cursor) ? "opBinary" : "opUnary";

    // to avoid problems, some C++ operators are translated as template functions,
    // but as seen in #114, don't do this if they're already templates!
    const templateParens = cursor.templateParams.length
        ? ""
        : "()";

    // Some of the operators here have empty parentheses around them. This is to
    // to make them templates and only be instantiated if needed. See #102.
    switch(cppOperator) {
        default:
            return dFunction ~ `(string op: "` ~ cppOperator ~ `")`;

        case "=": return `opAssign` ~ templateParens;
        case "()": return `opCall` ~ templateParens;
        case "[]": return `opIndex` ~ templateParens;
        case "==": return `opEquals` ~ templateParens;
    }
}

private bool isUnaryOperator(in from!"clang".Cursor cursor) @safe pure nothrow {
    return isOperator(cursor) && numParams(cursor) == 0;
}

private bool isBinaryOperator(in from!"clang".Cursor cursor) @safe pure nothrow {
    return isOperator(cursor) && numParams(cursor) == 1;
}

package long numParams(in from!"clang".Cursor cursor) @safe pure nothrow {
    import std.range: walkLength;
    return walkLength(cursor.type.paramTypes);
}

private string operatorSpellingCpp(in from!"clang".Cursor cursor,
                                   ref from!"dpp.runtime.context".Context context)
    @safe
    in(isOperator(cursor))
do
{
    import dpp.translation.type: translate;
    import dpp.translation.exception: UntranslatableException;
    import clang: Cursor;
    import std.string: replace;
    import std.algorithm: startsWith;

    const operator = cursor.spelling[OPERATOR_PREFIX.length .. $];

    if(cursor.kind == Cursor.Kind.ConversionFunction) {
        return "opCppCast_" ~ translate(cursor.returnType, context).replace(".", "_");
    }

    switch(operator) {
        default:
            if(operator.startsWith(`""`))  // user-defined string literal
                throw new UntranslatableException("Cannot translate user-defined literals");

            throw new UntranslatableException("Unknown C++ spelling for operator '" ~ operator ~ "'");

        case        "+":  return `opCppPlus`;
        case        "-":  return `opCppMinus`;
        case       "++":  return `opCppIncrement`;
        case       "--":  return `opCppDecrement`;
        case        "*":  return `opCppMul`;
        case        "/":  return `opCppDiv`;
        case        "&":  return `opCppAmpersand`;
        case        "~":  return `opCppTilde`;
        case        "%":  return `opCppMod`;
        case        "^":  return `opCppCaret`;
        case        "|":  return `opCppPipe`;
        case        "=":  return `opCppAssign`;
        case       ">>":  return `opCppRShift`;
        case       "<<":  return `opCppLShift`;
        case       "->":  return `opCppArrow`;
        case        "!":  return `opCppBang`;
        case       "&&":  return `opCppAnd`;
        case       "||":  return `opCppOr`;
        case        ",":  return `opCppComma`;
        case      "->*":  return `opCppArrowStar`;
        case       "+=":  return `opCppPlusAssign`;
        case       "-=":  return `opCppMinusAssign`;
        case       "*=":  return `opCppMulAssign`;
        case       "/=":  return `opCppDivAssign`;
        case       "%=":  return `opCppModAssign`;
        case       "^=":  return `opCppCaretAssign`;
        case       "&=":  return `opCppAmpersandAssign`;
        case       "|=":  return `opCppPipeAssign`;
        case      ">>=":  return `opCppRShiftAssign`;
        case      "<<=":  return `opCppLShiftAssign`;
        case       "()":  return `opCppCall`;
        case       "[]":  return `opCppIndex`;
        case       "==":  return `opCppEquals`;
        case       "!=":  return `opCppNotEquals`;
        case       "<=":  return `opCppLessEquals`;
        case       ">=":  return `opCppMoreEquals`;
        case        "<":  return `opCppLess`;
        case        ">":  return `opCppMore`;
        case      " new": return `opCppNew`;
        case    " new[]": return `opCppNewArray`;
        case   " delete": return `opCppDelete`;
        case " delete[]": return `opCppDeleteArray`;
    }

    assert(0);
}


// Add a non-const ref that forwards to the const ref copy ctor
// so that lvalues don't match the by-value ctor
private string[] maybeCopyCtor(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{

    import dpp.translation.dlang: maybeRename, maybePragma;
    import dpp.translation.type: translate;
    import clang: Cursor, Type;
    import std.array: front;

    if(!cursor.isCopyConstructor) return [];

    const param = cursor.type.paramTypes.front;
    const translated = translateFunctionParam(cursor, param, context);
    const dType = translated["ref const(".length .. $ - 1];  // remove the constness

    return [
        `this(ref ` ~ dType ~ ` other)`,
        `{`,
        `   this(*cast(const ` ~ dType ~ `*) &other);`,
        `}`,
    ];
}


private string[] maybeMoveCtor(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.dlang: maybeRename, maybePragma;
    import dpp.translation.type: translate;
    import clang: Cursor, Type;
    import std.array: front;

    if(!cursor.isMoveConstructor) return [];

    const paramType = cursor.type.paramTypes.front;
    const pointee = translate(paramType.pointee, context);

    return [
        // The actual C++ move constructor but declared to take a pointer
        maybePragma(cursor, context) ~ " this(" ~ pointee ~ "*);",
        // The fake D move constructor
        "this(" ~ translate(paramType, context) ~ " wrapper) {",
        "    this(wrapper.ptr);",
        // Hollow out moved-from value
        "    static if(is(typeof( { typeof(*wrapper.ptr) _; }   )))",
        "    {",
        "        typeof(*wrapper.ptr) init;",
        "        *wrapper.ptr = init;",
        "    }",
        "    else",
        "    {",
        "        import core.stdc.string: memset;",
        "        memset(wrapper.ptr, 0, typeof(*wrapper.ptr).sizeof);",
        "    }",
        "}",
        // The fake D by-value constructor imitating C++ semantics
        "this(" ~ pointee ~ " other)",
        "{",
        // Forward the call to the C++ move constructor
        "    this(&other);",
        "}",
    ];
}

// includes C variadic params
private auto translateAllParamTypes(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    in from!"std.typecons".Flag!"names" names = from!"std.typecons".No.names,
)
    @safe
{
    import clang: Cursor;
    import std.algorithm: endsWith, map;
    import std.range: enumerate, chain;
    import std.conv: text;

    // Here we used to check that if there were no parameters and the language is C,
    // then the correct translation in D would be (...);
    // However, that's not allowed in D. It just so happens that C production code
    // exists that doesn't bother with (void), so instead of producing something that
    // doesn't compile, we compromise and assume the user meant (void)

    auto paramTypes = translateParamTypes(cursor, cursor.type, context);

    const isVariadic =
        cursor.type.spelling.endsWith("...)")
        && cursor.kind != Cursor.Kind.FunctionTemplate
        ;
    const variadicParams = isVariadic ? ["..."] : [];

    return enumerate(chain(paramTypes, variadicParams))
        .map!(a => names ? a[1] ~ text(" arg", a[0]) : a[1])
        ;
}

// does not include C variadic params
auto translateParamTypes(in from!"clang".Cursor cursor,
                         in from!"clang".Type cursorType,
                         ref from!"dpp.runtime.context".Context context)
    @safe
{
    import std.algorithm: map;
    import std.range: tee, enumerate;

    return cursorType
        .paramTypes
        .enumerate
        .tee!((a) {
            context.log("    Function param #", a[0],
                        " type: ", a[1], "  canonical ", a[1].canonical);
        })
        .map!(t => translateFunctionParam(cursor, t[1], context))
        ;
}


// translate a ParmDecl
private string translateFunctionParam(in from!"clang".Cursor function_,
                                      in from!"clang".Type paramType,
                                      ref from!"dpp.runtime.context".Context context)
    @safe
{

    import dpp.translation.type: translate;
    import clang: Type, Language;
    import std.typecons: Yes;
    import std.array: replace;

    // Could be an opaque type
    const blob = blob(paramType, context);
    if(blob != "") return blob;

    // See #43
    const(Type) deunexpose(in Type type) {
        return type.kind == Type.Kind.Unexposed && function_.language != Language.CPlusPlus
            ? type.canonical
            : type;
    }

    // See contract.ctor.copy.definition.declartion for libclang silliness leading to this.
    // If the enclosing struct/class is templated and the function isn't, then we might
    // get "type-parameter-0-0" spellings even when the actual name is e.g. `T`.
    const numAggTemplateParams = function_.semanticParent.templateParams.length;
    const numFunTemplateParams = function_.templateParams.length;

    // HACK
    // FIXME: not sure what to do if the numbers aren't exactly 1 and 0
    const useAggTemplateParamSpelling = numAggTemplateParams == 1 && numFunTemplateParams == 0;
    const aggTemplateParamSpelling = useAggTemplateParamSpelling
        ? function_.semanticParent.templateParams[0].spelling
        : "";
    const translation = translate(deunexpose(paramType), context, Yes.translatingFunction);

    return useAggTemplateParamSpelling
        ? translation.replace("type_parameter_0_0", aggTemplateParamSpelling)
        : translation;
}


private string blob(in from!"clang".Type type,
                    in from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.type: translateOpaque;
    import clang: Type;
    import std.conv: text;

    // if the type is from an ignored namespace, use an opaque type, but not
    // if it's a pointer or reference - in that case the user can always
    // declare the type with no definition.
    if(context.isFromIgnoredNs(type) &&
       type.kind != Type.Kind.LValueReference &&
       type.kind != Type.Kind.Pointer)
    {
        return translateOpaque(type);
    }

    return "";
}


string[] translateInheritingConstructor(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context
    )
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.UsingDeclaration)
{
    import clang: Cursor;
    import std.algorithm: find, all;
    import std.array: empty, front;

    auto overloaded = cursor.children.find!(a => a.kind == Cursor.Kind.OverloadedDeclRef);
    if(overloaded.empty) return [];

    const allCtors = overloaded
        .front
        .children
        .all!(a => a.kind == Cursor.Kind.Constructor)
        ;

    if(!allCtors) return [];

    return [
        `this(_Args...)(auto ref _Args args) {`,
        `    import std.functional: forward;`,
        `    super(forward!args);`,
        `}`,
    ];
}
