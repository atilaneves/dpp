/**
   Translate aggregates
 */
module dpp.translation.aggregate;

import dpp.from;
import std.range: isInputRange;


enum MAX_BITFIELD_WIDTH = 64;


string[] translateStruct(in from!"clang".Cursor cursor,
                         ref from!"dpp.runtime.context".Context context)
    @safe
{
    return translateStrass(cursor, context, "struct");
}

string[] translateClass(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
{
    return translateStrass(cursor, context, "class");
}

// "strass" is a struct or class
private string[] translateStrass(in from!"clang".Cursor cursor,
                                 ref from!"dpp.runtime.context".Context context,
                                 in string cKeyword)
    @safe
{
    import clang: Cursor;
    import std.typecons: Nullable, nullable;
    import std.array: join;
    import std.conv: text;

    assert(
        cursor.kind == Cursor.Kind.StructDecl ||
        cursor.kind == Cursor.Kind.ClassDecl ||
        cursor.kind == Cursor.Kind.ClassTemplate ||
        cursor.kind == Cursor.Kind.ClassTemplatePartialSpecialization
    );

    string templateParamList(R)(R range) {
        return `(` ~ () @trusted { return range.join(", "); }() ~ `)`;
    }

    string templateSpelling(R)(in Cursor cursor, R range) {
        return cursor.spelling ~ templateParamList(range);
    }

    const spelling = () {

        // full template
        if(cursor.kind == Cursor.Kind.ClassTemplate)
            return nullable(templateSpelling(cursor, translateTemplateParams(cursor, context)));

        // partial or full template specialisation
        if(cursor.type.numTemplateArguments != -1)
            return nullable(templateSpelling(cursor, translateSpecialisedTemplateParams(cursor, context)));

        // non-template class/struct
        return Nullable!string();
    }();

    const dKeyword = "struct";

    return translateAggregate(context, cursor, cKeyword, dKeyword, spelling);
}


// Deal with full and partial template specialisations
// returns a range of string
private string[] translateSpecialisedTemplateParams(in from!"clang".Cursor cursor,
                                                    ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.type: translate;
    import clang: Type;
    import std.algorithm: map;
    import std.range: iota;
    import std.array: array, join;

    assert(cursor.type.numTemplateArguments != -1);

    if(isFromVariadicTemplate(cursor))
        return translateSpecialisedTemplateParamsVariadic(cursor, context);

    // get the original list of template parameters and translate them
    // e.g. template<bool, bool, typename> -> (bool V0, bool V1, T)
    const translatedTemplateParams = () @trusted {
        return translateTemplateParams(cursor, context)
        .array;
    }();

    // e.g. template<> struct foo<false, true, int32_t> -> 0:false, 1:true, 2: int
    string translateTemplateParamSpecialisation(in Type type, in int index) {
        return type.kind == Type.Kind.Invalid
            ? templateParameterSpelling(cursor, index)
            : translate(type, context);
    }

    // e.g. for template<> struct foo<false, true, int32_t>
    // 0 -> bool V0: false, 1 -> bool V1: true, 2 -> T0: int
    string element(in Type type, in int index) {
        // DELETE
        import std.conv: text;
        if(index >= translatedTemplateParams.length)
            throw new Exception(text("impossiburu! index:", index, " length: ", translatedTemplateParams.length,
                                     "\ncursor: ", cursor, "\ntype: ", type, "\nrange: ", cursor.sourceRange));

        string ret = translatedTemplateParams[index];  // e.g. `T`,  `bool V0`
        const maybeSpecialisation = translateTemplateParamSpecialisation(type, index);

        // type template arguments may be:
        // Invalid - value (could be specialised or not)
        // Unexposed - non-specialised type or
        // anything else - specialised type
        // The trick is figuring out if a value is specialised or not
        const isValue = type.kind == Type.Kind.Invalid;
        const isType = !isValue;
        const isSpecialised =
            (isValue && isValueOfType(cursor, context, index, maybeSpecialisation))
            ||
            (isType && type.kind != Type.Kind.Unexposed);

        if(isSpecialised) ret ~= ": " ~ maybeSpecialisation;

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
{
    import dpp.translation.type: translate;

    assert(isFromVariadicTemplate(cursor));
    assert(cursor.type.numTemplateArguments != -1);

    string[] ret;

    foreach(i; 0 .. cursor.type.numTemplateArguments) {
        ret ~= translate(cursor.type.typeTemplateArgument(i), context);
    }

    return ret;
}

// In the case cursor is a partial or full template specialisation,
// check to see if `maybeSpecialisation` can be converted to the
// indexth template parater of the cursor's original template.
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
    import std.array: array;
    import std.exception: collectException;
    import std.conv: to;

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
        default: throw new Exception("isValueOfType cannot handle type `" ~ dtype ~ "`");
        case "bool":   tryConvert!bool;   break;
        case "char":   tryConvert!char;   break;
        case "wchar":  tryConvert!wchar;  break;
        case "dchar":  tryConvert!dchar;  break;
        case "short":  tryConvert!short;  break;
        case "ushort": tryConvert!ushort; break;
        case "int":    tryConvert!int;    break;
        case "uint":   tryConvert!uint;   break;
        case "long":   tryConvert!long;   break;
        case "ulong":  tryConvert!long;   break;
    }

    return conversionException is null;
}

// returns the indexth template parameter value from a specialised
// template struct/class cursor (full or partial)
// e.g. template<> struct Foo<int, 42, double> -> 1: 42
private string templateParameterSpelling(in from!"clang".Cursor cursor, int index) {
    import std.algorithm: findSkip, until, OpenRight;
    import std.array: empty, save, split, array;
    import std.conv: text;

    auto spelling = cursor.type.spelling.dup;
    if(!spelling.findSkip("<")) return "";

    auto templateParams = spelling.until(">", OpenRight.yes).array.split(", ");

    return templateParams[index].text;
}

// Translates a C++ template parameter (value or type) to a D declaration
// e.g. template<typename, bool, typename> -> ["T0", "bool V0", "T1"]
// Returns a range of string
private auto translateTemplateParams(in from!"clang".Cursor cursor,
                                     ref from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.type: translate;
    import clang: Cursor;
    import std.conv: text;
    import std.algorithm: map, filter;
    import std.array: array;
    import std.range: enumerate;

    int templateParamIndex;  // used to generate names when there are none

    string newTemplateParamName() {
        return text("_TemplateParam_", templateParamIndex++);
    }

    string translateTemplateParam(in Cursor cursor) {
        import dpp.translation.type: translate;

        // The template parameter might be a value (bool, int, etc.)
        // or a type. If it's a value we get its type here.
        const maybeType = cursor.kind == Cursor.Kind.TemplateTypeParameter
            ? ""  // a type doesn't have a type
            : translate(cursor.type, context) ~ " ";

        // D requires template parameters to have names
        const spelling = cursor.spelling == "" ? newTemplateParamName : cursor.spelling;

        // e.g. "bool param", "T0"
        return maybeType ~ spelling;
    }

    auto templateParams = templateParams(cursor);
    auto translated = templateParams.map!translateTemplateParam.array;

    return () @trusted {
        return translated
            .enumerate
            .map!(a => a[1] ~ (cursor.isVariadicTemplate && a[0] == translated.length -1 ? "..." : ""))
        ;
    }();
}

// returns a range of cursors
private auto templateParams(in from!"clang".Cursor cursor)
    @safe
{

    import clang: Cursor;
    import std.algorithm: filter;

    const templateCursor = cursor.kind == Cursor.Kind.ClassTemplate
        ? cursor
        : cursor.specializedCursorTemplate;

    return templateCursor
        .children
        .filter!(a => a.kind == Cursor.Kind.TemplateTypeParameter || a.kind == Cursor.Kind.NonTypeTemplateParameter)
        ;
}

// If the original template is variadic
private bool isFromVariadicTemplate(in from!"clang".Cursor cursor) @safe {
    return isVariadicTemplate(cursor.specializedCursorTemplate);
}

private bool isVariadicTemplate(in from!"clang".Cursor cursor) @safe {
    import clang: Cursor, Token;
    import std.array: array;
    import std.algorithm: canFind;

    const templateParamChildren = () @trusted { return templateParams(cursor).array; }();

    return
        templateParamChildren.length > 0 &&
        templateParamChildren[$ - 1].kind == Cursor.Kind.TemplateTypeParameter &&
        cursor.tokens.canFind(Token(Token.Kind.Punctuation, "..."));
}



string[] translateUnion(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    assert(cursor.kind == Cursor.Kind.UnionDecl);
    return translateAggregate(context, cursor, "union");
}

string[] translateEnum(in from!"clang".Cursor cursor,
                       ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.typecons: nullable;

    assert(cursor.kind == Cursor.Kind.EnumDecl);

    // Translate it twice so that C semantics are the same (global names)
    // but also have a named version for optional type correctness and
    // reflection capabilities.
    // This means that `enum Foo { foo, bar }` in C will become:
    // `enum Foo { foo, bar }` _and_
    // `enum foo = Foo.foo; enum bar = Foo.bar;` in D.

    auto enumName = context.spellingOrNickname(cursor);

    string[] lines;
    foreach(member; cursor) {
        if(!member.isDefinition) continue;
        auto memName = member.spelling;
        lines ~= `enum ` ~ memName ~ ` = ` ~ enumName ~ `.` ~ memName ~ `;`;
    }

    return
        translateAggregate(context, cursor, "enum", nullable(enumName)) ~
        lines;
}

// not pure due to Cursor.opApply not being pure
string[] translateAggregate(
    ref from!"dpp.runtime.context".Context context,
    in from!"clang".Cursor cursor,
    in string keyword,
    in from!"std.typecons".Nullable!string spelling = from!"std.typecons".Nullable!string()
)
    @safe
{
    return translateAggregate(context, cursor, keyword, keyword, spelling);
}

private struct BitFieldInfo {

    import dpp.runtime.context: Context;
    import clang: Cursor;

    /// if the last seen member was a bitfield
    private bool lastMemberWasBitField;
    /// the combined (summed) bitwidths of the bitfields members seen so far
    private int totalBitWidth;
    /// to generate new names
    private int paddingNameIndex;

    string[] header(in Cursor cursor) @safe nothrow {
        import std.algorithm: any;

        if(cursor.children.any!(a => a.isBitField)) {
            // The align(4) is to mimic C. There, `struct Foo { int f1: 2; int f2: 3}`
            // would have sizeof 4, where as the corresponding bit fields in D would have
            // size 1. So we correct here. See issue #7.
            return [`    import std.bitmanip: bitfields;`, ``, `    align(4):`];
        } else
            return [];

    }

    string[] handle(in Cursor member) @safe pure nothrow {

        string[] lines;

        if(member.isBitField && !lastMemberWasBitField)
            lines ~= `    mixin(bitfields!(`;

        if(!member.isBitField && lastMemberWasBitField) lines ~= finishBitFields;

        if(member.isBitField && totalBitWidth + member.bitWidth > MAX_BITFIELD_WIDTH) {
            lines ~= finishBitFields;
            lines ~= `    mixin(bitfields!(`;
        }

        return lines;
    }

    void update(in Cursor member) @safe pure nothrow {
        lastMemberWasBitField = member.isBitField;
        if(member.isBitField) totalBitWidth += member.bitWidth;
    }

    string[] finish() @safe pure nothrow {
        return lastMemberWasBitField ? finishBitFields : [];
    }

    private string[] finishBitFields() @safe pure nothrow {
        import std.conv: text;


        int padding(in int totalBitWidth) {

            for(int powerOfTwo = 8; powerOfTwo <= MAX_BITFIELD_WIDTH; powerOfTwo *= 2) {
                if(powerOfTwo >= totalBitWidth) return powerOfTwo - totalBitWidth;
            }

            assert(0, text("Could not find powerOfTwo for width ", totalBitWidth));
        }

        const paddingBits = padding(totalBitWidth);

        string[] lines;

        if(paddingBits)
            lines ~= text(`        uint, "`, newPaddingName, `", `, padding(totalBitWidth));

        lines ~= `    ));`;

        totalBitWidth = 0;

        return lines;
    }

    private string newPaddingName() @safe pure nothrow {
        import std.conv: text;
        return text("_padding_", paddingNameIndex++);
    }

}

// not pure due to Cursor.opApply not being pure
string[] translateAggregate(
    ref from!"dpp.runtime.context".Context context,
    in from!"clang".Cursor cursor,
    in string cKeyword,
    in string dKeyword,
    in from!"std.typecons".Nullable!string spelling = from!"std.typecons".Nullable!string()
)
    @safe
{
    import dpp.translation.translation: translate;
    import clang: Cursor, Type;
    import std.algorithm: map;
    import std.array: array;

    // remember all aggregate declarations
    context.rememberAggregate(cursor);

    const name = spelling.isNull ? context.spellingOrNickname(cursor) : spelling.get;
    const realDlangKeyword = cursor.semanticParent.type.canonical.kind == Type.Kind.Record
        ? "static " ~ dKeyword
        : dKeyword;
    const firstLine = realDlangKeyword ~ ` ` ~ name;

    if(!cursor.isDefinition) return [firstLine ~ `;`];

    string[] lines;
    lines ~= firstLine;
    lines ~= `{`;

    if(cKeyword == "class") lines ~= "private:";

    BitFieldInfo bitFieldInfo;

    lines ~= bitFieldInfo.header(cursor);

    context.log("Children: ", cursor.children);

    foreach(member; cursor.children) {

        if(member.kind == Cursor.Kind.PackedAttr) {
            lines ~= "align(1):";
            continue;
        }

        lines ~= bitFieldInfo.handle(member);

        if(skipMember(member)) continue;

        lines ~= translate(member, context).map!(a => "    " ~ a).array;

        // Possibly deal with C11 anonymous structs/unions. See issue #29.
        lines ~= maybeC11AnonymousRecords(cursor, member, context);

        bitFieldInfo.update(member);
    }

    lines ~= bitFieldInfo.finish;
    lines ~= maybeOperators(cursor, name);
    lines ~= maybeDisableDefaultCtor(cursor, dKeyword);

    lines ~= `}`;

    return lines;
}


private bool skipMember(in from!"clang".Cursor member) @safe @nogc pure nothrow {
    import clang: Cursor;
    return
        !member.isDefinition
        && member.kind != Cursor.Kind.CXXMethod
        && member.kind != Cursor.Kind.Constructor
        && member.kind != Cursor.Kind.Destructor
        && member.kind != Cursor.Kind.VarDecl
        && member.kind != Cursor.Kind.CXXBaseSpecifier
        && member.kind != Cursor.Kind.ConversionFunction
    ;
}


string[] translateField(in from!"clang".Cursor field,
                        ref from!"dpp.runtime.context".Context context)
    @safe
{

    import dpp.translation.dlang: maybeRename;
    import dpp.translation.type: translate;
    import clang: Cursor, Type;
    import std.conv: text;
    import std.typecons: No;
    import std.array: replace;

    assert(field.kind == Cursor.Kind.FieldDecl, text("Field of wrong kind: ", field));

    // The field could be a pointer to an undeclared struct or a function pointer with parameter
    // or return types that are a pointer to an undeclared struct. We have to remember these
    // so as to be able to declare the structs for D consumption after the fact.
    if(field.type.kind == Type.Kind.Pointer) maybeRememberStructsFromType(field.type, context);

    // Remember the field name in case it ends up clashing with a type.
    context.rememberField(field.spelling);

    const type = translate(field.type, context, No.translatingFunction);

    return field.isBitField
        ? translateBitField(field, context, type)
        : [text(type, " ", maybeRename(field, context), ";")];
}

string[] translateBitField(in from!"clang".Cursor cursor,
                           ref from!"dpp.runtime.context".Context context,
                           in string type)
    @safe
{
    import dpp.translation.dlang: maybeRename;
    import std.conv: text;

    auto spelling = maybeRename(cursor, context);
    // std.bitmanip.bitfield can't handle successive mixins with
    // no name. See issue #35.
    if(spelling == "") spelling = context.newAnonymousMemberName;

    return [text("    ", type, `, "`, spelling, `", `, cursor.bitWidth, `,`)];
}

private void maybeRememberStructsFromType(in from!"clang".Type type,
                                          ref from!"dpp.runtime.context".Context context)
    @safe pure
{
    import clang: Type;
    import std.range: only, chain;

    const pointeeType = type.pointee.canonical;
    const isFunction =
        pointeeType.kind == Type.Kind.FunctionProto ||
        pointeeType.kind == Type.Kind.FunctionNoProto;

    if(pointeeType.kind == Type.Kind.Record)
        maybeRememberStructs([type], context);
    else if(isFunction)
        maybeRememberStructs(chain(only(pointeeType.returnType), pointeeType.paramTypes),
                             context);
}

void maybeRememberStructs(R)(R types, ref from!"dpp.runtime.context".Context context)
    @safe pure if(isInputRange!R)
{
    import dpp.translation.type: translate;
    import clang: Type;
    import std.algorithm: map, filter;

    auto structTypes = types
        .filter!(a => a.kind == Type.Kind.Pointer && a.pointee.canonical.kind == Type.Kind.Record)
        .map!(a => a.pointee.canonical);

    void rememberStruct(in Type pointeeCanonicalType) {
        const translatedType = translate(pointeeCanonicalType, context);
        // const becomes a problem if we have to define a struct at the end of all translations.
        // See it.compile.projects.nv_alloc_ops
        enum constPrefix = "const(";
        const cleanedType = pointeeCanonicalType.isConstQualified
            ? translatedType[constPrefix.length .. $-1] // unpack from const(T)
            : translatedType;

        if(cleanedType != "va_list")
            context.rememberFieldStruct(cleanedType);
    }

    foreach(structType; structTypes)
        rememberStruct(structType);
}

// if the cursor is an aggregate in C, i.e. struct, union or enum
package bool isAggregateC(in from!"clang".Cursor cursor) @safe @nogc pure nothrow {
    import clang: Cursor;
    return
        cursor.kind == Cursor.Kind.StructDecl ||
        cursor.kind == Cursor.Kind.UnionDecl ||
        cursor.kind == Cursor.Kind.EnumDecl;
}


private string[] maybeC11AnonymousRecords(in from!"clang".Cursor cursor,
                                          in from!"clang".Cursor member,
                                          ref from!"dpp.runtime.context".Context context)
    @safe

{
    import dpp.translation.type: translate, hasAnonymousSpelling;
    import clang: Cursor, Type;
    import std.algorithm: any, filter;

    if(member.type.kind != Type.Kind.Record || member.spelling != "") return [];

    // Either a field or an array of the type we expect
    bool isFieldOfRightType(in Cursor member, in Cursor child) {
        const isField =
            child.kind == Cursor.Kind.FieldDecl &&
            child.type.canonical == member.type.canonical;

        const isArrayOf = child.type.elementType.canonical == member.type.canonical;
        return isField || isArrayOf;
    }

    // Check if the parent cursor has any fields have this type.
    // If so, we don't need to declare a dummy variable.
    const anyFields = cursor.children.any!(a => isFieldOfRightType(member, a));
    if(anyFields) return [];

    string[] lines;
    const varName = context.newAnonymousMemberName;

    //lines ~= "    " ~ translate(member.type, context) ~ " " ~  varName ~ ";";
    const dtype = translate(member.type, context);
    lines ~= "    " ~ dtype ~ " " ~  varName ~ ";";

    foreach(subMember; member.children) {
        if(subMember.kind == Cursor.Kind.FieldDecl)
            lines ~= innerFieldAccessors(varName, subMember);
        else if(subMember.type.canonical.kind == Type.Kind.Record &&
                hasAnonymousSpelling(subMember.type.canonical) &&
                !member.children.any!(a => isFieldOfRightType(subMember, a))) {
            foreach(subSubMember; subMember) {
                lines ~= "        " ~ innerFieldAccessors(varName, subSubMember);
            }
        }
    }

    return lines;
}


// functions to emulate C11 anonymous structs/unions
private string[] innerFieldAccessors(in string varName, in from !"clang".Cursor subMember) @safe {
    import std.format: format;
    import std.algorithm: map;
    import std.array: array;

    string[] lines;

    const fieldAccess = varName ~ "." ~ subMember.spelling;
    const funcName = subMember.spelling;

    lines ~= q{auto %s() @property @nogc pure nothrow { return %s; }}
        .format(funcName, fieldAccess);

    lines ~= q{void %s(_T_)(auto ref _T_ val) @property @nogc pure nothrow { %s = val; }}
        .format(funcName, fieldAccess);

    return lines.map!(a => "    " ~ a).array;
}

// emit a D opCmp if the cursor has operator<, operator> and operator==
private string[] maybeOperators(in from!"clang".Cursor cursor, in string name)
    @safe
{
    import dpp.translation.function_: OPERATOR_PREFIX;
    import std.algorithm: map, any;
    import std.array: array;

    string[] lines;

    bool hasOperator(in string op) {
        return cursor.children.any!(a => a.spelling == OPERATOR_PREFIX ~ op);
    }

    if(hasOperator(">") && hasOperator("<") && hasOperator("==")) {
        lines ~=  [
            `int opCmp(` ~ name ~ ` other) const`,
            `{`,
            `    if(this.opCppLess(other)) return -1;`,
            `    if(this.opCppMore(other)) return  1;`,
            `    return 0;`,
            `}`,
        ].map!(a => `    ` ~ a).array;
    }

    if(hasOperator("!")) {
        lines ~= [
            `bool opCast(T: bool)() const`,
            `{`,
            `    return !this.opCppBang();`,
            `}`,
        ].map!(a => `    ` ~ a).array;
    }

    return lines;
}

private string[] maybeDisableDefaultCtor(in from!"clang".Cursor cursor, in string dKeyword)
    @safe
{
    import clang: Cursor;
    import std.algorithm: any;

    if(dKeyword == "struct" &&
       cursor.children.any!(a => a.kind == Cursor.Kind.Constructor)) {
        return [`    @disable this();`];
    }

    return [];
}
