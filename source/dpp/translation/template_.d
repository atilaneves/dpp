/**
   C++ template translations
 */
module dpp.translation.template_;


import dpp.from;


string templateParamList(R)(R range) {
    import std.array: join;
    return `(` ~ () @trusted { return range.join(", "); }() ~ `)`;
}

string templateSpelling(R)(in from!"clang".Cursor cursor, R range) {
    return cursor.spelling ~ templateParamList(range);
}


// Deal with full and partial template specialisations
package string[] translateSpecialisedTemplateParams(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.type.numTemplateArguments != -1)
    do
{
    return isFromVariadicTemplate(cursor)
        ? translateSpecialisedTemplateParamsVariadic(cursor, context)
        : translateSpecialisedTemplateParamsFinite(cursor, context);
}


private string[] translateSpecialisedTemplateParamsFinite(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.type: translate, templateArgumentKind, TemplateArgumentKind,
        translateTemplateParamSpecialisation;
    import clang: Type;
    import std.algorithm: map;
    import std.range: iota;
    import std.array: array, join;
    import std.typecons: No;
    import std.conv: text;

    // get the original list of template parameters and translate them
    // e.g. template<bool, bool, typename> -> (bool V0, bool V1, T)
    const translatedTemplateParams = () @trusted {
        return translateTemplateParams(cursor, context, No.defaults)
        .array;
    }();

    // e.g. for template<> struct foo<false, true, int32_t>
    // 0 -> `bool V0: false`, 1 -> `bool V1: true`, 2 -> `T0: int`
    string element(in Type templateArgType, in int index) {

        import dpp.translation.exception: UntranslatableException;

        string errorMsg(in string keyword) {
            import std.conv: text;
            return text("Cannot translate ", index, "th template arg of ", cursor, " due to `",
                        keyword, "` template type parameter specialisation");
        }

        if(templateArgType.isConstQualified)
            throw new UntranslatableException(errorMsg(`const`));

        if(templateArgType.isVolatileQualified)
            throw new UntranslatableException(errorMsg(`volatile`));

        if(index > translatedTemplateParams.length)
            throw new UntranslatableException(
                text("template index (",
                     index, ") larger than parameter length:\n",
                     translatedTemplateParams));

        string ret = translatedTemplateParams[index];  // e.g. `T`,  `bool V0`
        const maybeSpecialisation = translateTemplateParamSpecialisation(cursor.type, templateArgType, index, context);
        const templateArgKind = templateArgumentKind(templateArgType);

        with(TemplateArgumentKind) {
            const isSpecialised =
                templateArgKind == SpecialisedType ||
                (templateArgKind == Value && isValueOfType(cursor, context, index, maybeSpecialisation));

            if(isSpecialised) ret ~= ": " ~ maybeSpecialisation;
        }

        return ret;
    }

    return () @trusted {
        return
            cursor.type.numTemplateArguments
            .iota
            .map!(i => element(cursor.type.typeTemplateArgument(i), i))
            .array
            ;
    }();
}


// FIXME: refactor
private auto translateSpecialisedTemplateParamsVariadic(in from!"clang".Cursor cursor,
                                                        ref from!"dpp.runtime.context".Context context)
    @safe
    in(isFromVariadicTemplate(cursor) && cursor.type.numTemplateArguments != -1)
    do
{
    import dpp.translation.type: translate;

    string[] ret;

    foreach(i; 0 .. cursor.type.numTemplateArguments) {
        ret ~= translate(cursor.type.typeTemplateArgument(i), context);
    }

    return ret;
}

// In the case cursor is a partial or full template specialisation,
// check to see if `maybeSpecialisation` can be converted to the
// indexth template parameter of the cursor's original template.
// If it can, then it's a value of that type.
private bool isValueOfType(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    in int index,
    in string maybeSpecialisation,
    )
    @safe
{
    import dpp.translation.type: translate;
    import dpp.translation.exception: UntranslatableException;
    import std.array: array;
    import std.exception: collectException;
    import std.conv: to;
    import core.stdc.config: c_long, c_ulong;

    // the original template cursor (no specialisations)
    const templateCursor = cursor.specializedCursorTemplate;
    // the type of the indexth template parameter
    const templateParamCursor = () @trusted { return templateCursor.templateParams.array[index]; }();
    // the D translation of that type
    const dtype = translate(templateParamCursor.type, context);

    Exception conversionException;

    void tryConvert(T)() {
        conversionException = collectException(maybeSpecialisation.to!T);
    }

    switch(dtype) {
        default: throw new UntranslatableException("isValueOfType cannot handle type `" ~ dtype ~ "`");
        case "bool":    tryConvert!bool;    break;
        case "char":    tryConvert!char;    break;
        case "wchar":   tryConvert!wchar;   break;
        case "dchar":   tryConvert!dchar;   break;
        case "short":   tryConvert!short;   break;
        case "ushort":  tryConvert!ushort;  break;
        case "int":     tryConvert!int;     break;
        case "uint":    tryConvert!uint;    break;
        case "long":    tryConvert!long;    break;
        case "ulong":   tryConvert!ulong;   break;
        case "c_ulong": tryConvert!c_ulong; break;
        case "c_long":  tryConvert!c_long;  break;
    }

    return conversionException is null;
}


// Translates a C++ template parameter (value or type) to a D declaration
// e.g. `template<typename, bool, typename>` -> ["T0", "bool V0", "T1"]
// Returns a range of string
package auto translateTemplateParams(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    from!"std.typecons".Flag!"defaults" defaults = from!"std.typecons".Yes.defaults,
    ) @safe
{
    import dpp.translation.type: translate, translateString;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map, filter, countUntil;
    import std.array: array;
    import std.range: enumerate;

    int templateParamIndex;  // used to generate names when there are none

    string newTemplateParamName() {
        // FIXME
        // the naming convention is to match what libclang gives, but there's no
        // guarantee that it'll always match.
        return text("type_parameter_0_", templateParamIndex++);
    }

    // translate a template parameter cursor
    string translateTemplateParam(in long index, in Cursor templateParam) {
        import dpp.translation.type: translate;
        import dpp.translation.tokens: translateTokens;
        import clang: Token;

        // The template parameter might be a value (bool, int, etc.)
        // or a type. If it's a value we get its type here.
        const maybeType =
            // a type doesn't have a type
            templateParam.kind == Cursor.Kind.TemplateTypeParameter
            // In C++, variadic templates can be values of a type, e.g.
            // `template<int...>`
            // The only way to declare this in D would be using a template contraint,
            // but the main declaration just needs a name and the ellipsis - in D variadic
            // templates can be types, values, or symbols. To prevent us from trying to
            // declare in D `int param...`, which isn't valid, we don't use the type of
            // a value parameter if it's variadic
            || (cursor.isVariadicTemplate && index == cursor.templateParams.length - 1)
            ? ""
            : translate(templateParam.type, context) ~ " ";

        // D requires template parameters to have names
        const spelling = templateParam.spelling == "" ? newTemplateParamName : templateParam.spelling;

        // There's no direct way to extract default template parameters from libclang
        // so we search for something like `T = Foo` in the tokens
        const equalIndex = templateParam.tokens.countUntil!(t => t.kind == Token.Kind.Punctuation &&
                                                                 t.spelling == "=");

        const maybeDefault = equalIndex == -1 || !defaults
            ? ""
            : templateParam.tokens[equalIndex .. $]
                .array
                .translateTokens
            ;

        // e.g. "bool param", "T0"
        return maybeType ~ spelling ~ maybeDefault;
    }

    auto templateParams = cursor.templateParams;
    context.log("Children: ", cursor.children);
    context.log("Template Params: ", templateParams);
    auto translated = templateParams
        .enumerate
        .map!(a => translateTemplateParam(a[0], a[1]))
        ;

    // might need to be a variadic parameter
    string maybeVariadic(in long index, in string name) {
        return cursor.isVariadicTemplate && index == translated.length - 1
            // If it's variadic, come up with a new name in case it's variadic
            // values. D doesn't really care.
            ? name ~ "..."
            : name;
    }

    return () @trusted {
        return translated
            .enumerate
            .map!(a => maybeVariadic(a[0], a[1]))
        ;
    }();
}

// If the original template is variadic
private bool isFromVariadicTemplate(in from!"clang".Cursor cursor) @safe {
    return isVariadicTemplate(cursor.specializedCursorTemplate);
}

private bool isVariadicTemplate(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor, Token;
    import std.array: array;
    import std.algorithm: canFind, countUntil;

    const templateParamChildren = () @trusted { return cursor.templateParams.array; }();

    // There might be a "..." token inside the body of the struct/class, and we don't want to
    // look at that. So instead we stop looking at tokens when the struct/class definition begins.
    const closeAngleIndex = cursor.tokens.countUntil!(a => a.kind ==
                                                      Token.Kind.Punctuation &&
                                                      (a.spelling == ">" || a.spelling == ">>"));
    const tokens = closeAngleIndex == -1 ? cursor.tokens : cursor.tokens[0 .. closeAngleIndex];

    return tokens.canFind(Token(Token.Kind.Punctuation, "..."));
}


// e.g. `template <typename T> using foo = bar;`
string[] translateTypeAliasTemplate(in from!"clang".Cursor cursor,
                                    ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.TypeAliasTemplateDecl)
do
{
    import dpp.translation.type: translate;
    import dpp.translation.exception: UntranslatableException;
    import clang: Cursor, Type;
    import std.conv: text;
    import std.algorithm: countUntil;
    import std.typecons: No;
    import std.array: join, replace;

    // see contract.templates.using
    const typeAliasIndex = cursor.children.countUntil!(c => c.kind == Cursor.Kind.TypeAliasDecl);
    assert(typeAliasIndex != -1, text(cursor.children));
    const typeAlias = cursor.children[typeAliasIndex];

    const underlying = () {
        if(typeAlias.underlyingType.kind == Type.Kind.Unexposed) {

            const templateRefIndex = typeAlias
            .children
            .countUntil!(c => c.kind == Cursor.Kind.TemplateRef);

            if(templateRefIndex < 0 || templateRefIndex >= typeAlias.children.length)
                throw new UntranslatableException(
                    text("templateRefIndex (", templateRefIndex, ") out of bounds. Children:\n", typeAlias.children));

            const templateRef = typeAlias.children[templateRefIndex];
            return templateRef.spelling;

        } else
            return translate(typeAlias.underlyingType, context, No.translatingFunction);
    }();

    // FIXME
    // Not sure what to do here to be able to satisfy both:
    // ----------
    // template<typename T> struct bar;
    // template<typename T> using foo = bar;
    // ----------
    // And:
    // ----------
    // template<typename...> using void_t = void;
    // ----------
    // The first one can be either `alias foo = bar` or `alias foo(T) = bar(T)`
    // but the 2nd one has to be `alias void_t(T...) = void`.
    // The first example has to have the same template arguments on both sides,
    // the second needs it only on the left.
    const templateParams = isVariadicTemplate(cursor)
        ? "(" ~ translateTemplateParams(cursor, context).join(", ") ~ ")"
        : "";

    return [text("alias ", cursor.spelling, templateParams ~ " = ", underlying, ";")];
}
