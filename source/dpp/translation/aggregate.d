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
    import clang: Token;
    import std.algorithm: canFind;

    const cKeyword = cursor.tokens.canFind(Token(Token.Kind.Keyword, "class"))
        ? "class"
        : "struct";

    return translateStrass(cursor, context, cKeyword);
}

// "strass" is a struct or class
private string[] translateStrass(in from!"clang".Cursor cursor,
                                 ref from!"dpp.runtime.context".Context context,
                                 in string cKeyword)
    @safe
  in(isStrass(cursor))
  do
{
    import dpp.translation.template_: templateSpelling, translateTemplateParams,
        translateSpecialisedTemplateParams;
    import clang: Cursor;
    import std.typecons: Nullable, nullable;
    import std.array: join;
    import std.conv: text;

    Nullable!string spelling() {

        // full template
        if(cursor.kind == Cursor.Kind.ClassTemplate)
            return nullable(templateSpelling(cursor, translateTemplateParams(cursor, context)));

        // partial or full template specialisation
        if(cursor.type.numTemplateArguments != -1)
            return nullable(templateSpelling(cursor, translateSpecialisedTemplateParams(cursor, context)));

        // non-template class/struct
        return Nullable!string();
    }

    const dKeyword = dKeywordFromStrass(cursor);

    return translateAggregate(context, cursor, cKeyword, dKeyword, spelling);
}


private bool isStrass(in from!"clang".Cursor cursor) @safe @nogc pure nothrow {
    return
        cursor.kind == from!"clang".Cursor.Kind.StructDecl ||
        cursor.kind == from!"clang".Cursor.Kind.ClassDecl ||
        cursor.kind == from!"clang".Cursor.Kind.ClassTemplate ||
        cursor.kind == from!"clang".Cursor.Kind.ClassTemplatePartialSpecialization
        ;
}


// Decide on whether to emit a D struct or class
package string dKeywordFromStrass(in from!"clang".Cursor cursor) @safe nothrow {
    import dpp.clang: baseClasses;
    import clang: Cursor;
    import std.algorithm: any, map, filter;
    import std.range: walkLength;

    static bool hasVirtuals(in Cursor cursor) {
        return cursor.children.any!(a => a.isVirtual);
    }

    static bool anyVirtualInAncestry(in Cursor cursor) @safe nothrow {
        if(hasVirtuals(cursor)) return true;

        return cursor.baseClasses.any!anyVirtualInAncestry;
    }

    return anyVirtualInAncestry(cursor)
        ? "class"
        : "struct";
}


string[] translateUnion(in from!"clang".Cursor cursor,
                        ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.UnionDecl)
    do
{
    import clang: Cursor;
    return translateAggregate(context, cursor, "union");
}


string[] translateEnum(in from!"clang".Cursor cursor,
                       ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.EnumDecl)
    do
{
    import dpp.translation.dlang: maybeRename;
    import clang: Cursor, Token;
    import std.typecons: nullable;
    import std.algorithm: canFind;

    const enumName = context.spellingOrNickname(cursor);
    string[] lines;

    const isEnumClass = cursor.tokens.canFind(Token(Token.Kind.Keyword, "class"));

    if(!isEnumClass && !context.options.alwaysScopedEnums) {
        // Translate it twice so that C semantics are the same (global names)
        // but also have a named version for optional type correctness and
        // reflection capabilities.
        // This means that `enum Foo { foo, bar }` in C will become:
        // `enum Foo { foo, bar }` _and_
        // `enum foo = Foo.foo; enum bar = Foo.bar;` in D.

        foreach(member; cursor) {
            if(!member.isDefinition) continue;
            auto memName = maybeRename(member, context);
            lines ~= `enum ` ~ memName ~ ` = ` ~ enumName ~ `.` ~ memName ~ `;`;
        }
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
    import dpp.translation.type: hasAnonymousSpelling;
    import dpp.runtime.context: Language;
    import clang: Cursor, Type, AccessSpecifier;
    import std.algorithm: map;
    import std.array: array;

    // remember all aggregate declarations
    context.rememberAggregate(cursor);

    const name = spelling.isNull ? context.spellingOrNickname(cursor) : spelling.get;
    const realDlangKeyword = cursor.semanticParent.type.canonical.kind == Type.Kind.Record
        ? "static " ~ dKeyword
        : dKeyword;
    const parents = maybeParents(cursor, context, dKeyword);
    const enumBaseType = maybeEnumBaseType(cursor, dKeyword);
    const firstLine = realDlangKeyword ~ ` ` ~ name ~ parents ~ enumBaseType;

    if(!cursor.isDefinition) return [firstLine ~ `;`];

    string[] lines;
    lines ~= firstLine;
    lines ~= `{`;

    // In C++ classes have private access as default
    if(cKeyword == "class") {
        lines ~= "private:";
        context.accessSpecifier = AccessSpecifier.Private;
    } else
        context.accessSpecifier = AccessSpecifier.Public;

    BitFieldInfo bitFieldInfo;

    lines ~= bitFieldInfo.header(cursor);

    context.log("Children: ", cursor.children);

    foreach(i, child; cursor.children) {

        if(child.kind == Cursor.Kind.PackedAttr) {
            lines ~= "align(1):";
            continue;
        }

        if(skipMember(child)) continue;

        lines ~= bitFieldInfo.handle(child);

        if (context.language == Language.C
                && (child.type.kind == Type.Kind.Record || child.type.kind == Type.Kind.Enum)
                && !child.type.hasAnonymousSpelling)
            context.rememberAggregateParent(child, cursor);

        const childTranslation = () {

            if(isPrivateField(child, context))
                return translatePrivateMember(child);

            if(child.kind == Cursor.Kind.CXXBaseSpecifier && dKeyword == "struct")
                return translateStructBase(i, child, context);

            return translate(child, context);
        }();

        lines ~= childTranslation.map!(a => "    " ~ a).array;

        // Possibly deal with C11 anonymous structs/unions. See issue #29.
        lines ~= maybeC11AnonymousRecords(cursor, child, context);

        bitFieldInfo.update(child);
    }

    lines ~= bitFieldInfo.finish;
    lines ~= maybeOperators(cursor, name);
    lines ~= maybeDisableDefaultCtor(cursor, dKeyword);

    lines ~= `}`;

    return lines;
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

private bool isPrivateField(in from!"clang".Cursor cursor,
                            in from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor, AccessSpecifier;

    const isField =
        cursor.kind == Cursor.Kind.FieldDecl ||
        cursor.kind == Cursor.Kind.VarDecl;

    return
        context.accessSpecifier == AccessSpecifier.Private
        && isField
        // The reason for this is templated types have negative sizes according
        // to libclang, even if they're fully instantiated...
        // So even though they're private, they can't be declared as opaque
        // binary blobs because we don't know how large they are.
        && cursor.type.getSizeof > 0
        ;

}

// Since one can't access private members anyway, why bother translating?
// Declare an array of equivalent size in D, helps with the untranslatable
// parts of C++
private string[] translatePrivateMember(in from!"clang".Cursor cursor) @safe {
    import dpp.translation.type: translateOpaque;

    return cursor.type.getSizeof > 0
        ? [ translateOpaque(cursor.type) ~ ` ` ~ cursor.spelling ~ `;`]
        : [];
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
        && member.kind != Cursor.Kind.FunctionTemplate
        && member.kind != Cursor.Kind.UsingDeclaration
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

private from!"clang".Type pointeeTypeFor(in from!"clang".Type type)
    @safe
{
    import clang: Type;

    Type pointeeType = type.pointee.canonical;
    while (pointeeType.kind == Type.Kind.Pointer)
        pointeeType = pointeeType.pointee.canonical;

    return pointeeType;
}

// C allows elaborated types to appear in function parameters and member declarations
// if they're pointers and doesn't require a declaration for the referenced type.
private void maybeRememberStructsFromType(in from!"clang".Type type,
                                          ref from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Type;
    import std.range: only, chain;

    const pointeeType = pointeeTypeFor(type);
    const isFunction =
        pointeeType.kind == Type.Kind.FunctionProto ||
        pointeeType.kind == Type.Kind.FunctionNoProto;

    if(pointeeType.kind == Type.Kind.Record)
        // can't use `only` with `const` for some reason
        maybeRememberStructs([type], context);
    else if(isFunction)
        maybeRememberStructs(chain(only(pointeeType.returnType), pointeeType.paramTypes),
                             context);
}


// C allows elaborated types to appear in function parameters and member declarations
// if they're pointers and doesn't require a declaration for the referenced type.
void maybeRememberStructs(R)(R types, ref from!"dpp.runtime.context".Context context)
    @safe if(isInputRange!R)
{
    import dpp.translation.type: translate;
    import clang: Type;
    import std.algorithm: map, filter;

    auto structTypes = types
        .filter!(a => a.kind == Type.Kind.Pointer && pointeeTypeFor(a).kind == Type.Kind.Record)
        .map!(a => pointeeTypeFor(a));

    void rememberStruct(scope const Type pointeeCanonicalType) @safe {
        import dpp.translation.type: translateElaborated;
        import std.array: replace;
        import std.algorithm: canFind;

        // If it's not a C elaborated type, we don't need to do anything.
        // The only reason this code exists is because elaborated types
        // can be used in function signatures or member declarations
        // without a declaration for the struct itself as long as it's
        // a pointer.
        if(!pointeeCanonicalType.spelling.canFind("struct ") &&
           !pointeeCanonicalType.spelling.canFind("union ") &&
           !pointeeCanonicalType.spelling.canFind("enum "))
            return;

        const removeConst = pointeeCanonicalType.isConstQualified
            ? pointeeCanonicalType.spelling.replace("const ", "")
            : pointeeCanonicalType.spelling;
        const removeVolatile = pointeeCanonicalType.isVolatileQualified
            ? removeConst.replace("volatile ", "")
            : removeConst;

        context.rememberFieldStruct(translateElaborated(removeVolatile, context));
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
    static bool isFieldOfRightType(in Cursor member, in Cursor child) {
        const isField =
            child.kind == Cursor.Kind.FieldDecl &&
            (child.type.canonical == member.type.canonical ||
                // If the inner struct declaration is 'const struct {...} X;',
                // then child.type.canonical would be:
                // Type(Elaborated, "const struct (anonymous struct at fileY)"),
                // and member.type.canonical would be:
                // Type(Record, "struct ParentStruct::(anonymous at fileY)").
                // This is the reason why we unelaborate the child.type.
                child.type.unelaborate == member.type.canonical);

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

    static string[] subMemberAccessors(in Cursor member,
                                       in string varName,
                                       ref from!"dpp.runtime.context".Context context) {
        string[] res;
        foreach(subMember; member.children) {
            if(subMember.kind == Cursor.Kind.FieldDecl)
                res ~= innerFieldAccessors(varName, subMember, context);
            else if(subMember.type.canonical.kind == Type.Kind.Record &&
                    hasAnonymousSpelling(subMember.type.canonical) &&
                    !member.children.any!(a => isFieldOfRightType(subMember, a))) {
                res ~= subMemberAccessors(subMember, varName, context);
            }
        }
        return res;
    }

    lines ~= subMemberAccessors(member, varName, context);

    return lines;
}


// functions to emulate C11 anonymous structs/unions
private string[] innerFieldAccessors(in string varName,
                                     in from !"clang".Cursor subMember,
                                     ref from!"dpp.runtime.context".Context context) @safe {
    import std.format: format;
    import std.algorithm: map;
    import std.array: array;

    string[] lines;

    const subMemberSpelling = context.spelling(subMember.spelling);
    const fieldAccess = varName ~ "." ~ subMemberSpelling;
    const funcName = subMemberSpelling;

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
    import std.array: array, replace;

    string[] lines;

    bool hasOperator(in string op) {
        return cursor.children.any!(a => a.spelling == OPERATOR_PREFIX ~ op);
    }

    // if the aggregate has a parenthesis in its name it's because it's a templated
    // struct/class, in which case the parameter has to have an exclamation mark.
    const typeName = name.replace("(", "!(");

    if(hasOperator(">") && hasOperator("<") && hasOperator("==")) {
        lines ~=  [
            `int opCmp()(` ~ typeName ~ ` other) const`,
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
    import dpp.translation.function_: numParams;
    import clang: Cursor;
    import std.algorithm: any;

    bool hasNoArgsCtor(in Cursor child) {
        return child.kind == Cursor.Kind.Constructor &&
            numParams(child) == 0;
    }

    if(dKeyword == "struct" &&
       cursor.children.any!hasNoArgsCtor) {
        return [`    @disable this();`];
    }

    return [];
}


private string[] translateStructBase(size_t index,
                                     in from!"clang".Cursor cursor,
                                     ref from!"dpp.runtime.context".Context context)
    @safe
    in(cursor.kind == from!"clang".Cursor.Kind.CXXBaseSpecifier)
do
{
    import dpp.translation.type: translate;
    import std.typecons: No;
    import std.algorithm: canFind;
    import std.conv: text;

    const type = translate(cursor.type, context, No.translatingFunction);

    // FIXME - see it.cpp.templates.__or_
    // Not only would that test fail if this weren't here, but the spelling of
    // the type parameters would be completely wrong as well.
    if(type.canFind("...")) return [];

    // FIXME - type traits failures due to inheritance
    if(type.canFind("&")) return [];

    const fieldName = text("_base", index);
    auto fieldDecl = type ~ " " ~ fieldName ~ ";";
    auto maybeAliasThis = index == 0
        ? [`alias ` ~ fieldName ~ ` this;`]
        : [];

    return fieldDecl ~ maybeAliasThis;
}


private string maybeParents(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
    in string dKeyword)
    @safe
{
    import dpp.translation.type: translate;
    import clang: Cursor;
    import std.typecons: No;
    import std.algorithm: filter, map;
    import std.array: join;

    if(dKeyword != "class") return "";

    auto parents = cursor
        .children
        .filter!(a => a.kind == Cursor.Kind.CXXBaseSpecifier)
        .map!(a => translate(a.type, context, No.translatingFunction))
        ;

    return parents.empty
        ? ""
        : ": " ~ parents.join(", ");
}

private string maybeEnumBaseType(in from!"clang".Cursor cursor, in string dKeyword)
    @safe
{
    import std.algorithm: map, minElement, maxElement;

    if(dKeyword != "enum") return "";

    auto enumValues = cursor.children.map!(a => a.enumConstantValue);
    bool shouldPromote = enumValues.maxElement > int.max || enumValues.minElement < int.min;

    return shouldPromote ? " : long" : "";
}
