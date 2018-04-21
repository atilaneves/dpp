/**
   Cursor translations
 */
module dpp.cursor.translation;

import dpp.from;

alias Translator = string[] function(
    in from!"clang".Cursor cursor,
    ref from!"dpp.runtime.context".Context context,
) @safe;

string translateTopLevelCursor(in from!"clang".Cursor cursor,
                               ref from!"dpp.runtime.context".Context context,
                               in string file = __FILE__,
                               in size_t line = __LINE__)
    @safe
{
    import std.array: join;
    import std.algorithm: map;

    return cursor.skipTopLevel
        ? ""
        : translate(cursor, context, file, line).map!(a => "    " ~ a).join("\n");
}

private bool skipTopLevel(in from!"clang".Cursor cursor) @safe pure {
    import dpp.cursor.aggregate: isAggregateC;
    import clang: Cursor;
    import std.algorithm: startsWith, canFind;

    // don't bother translating top-level anonymous aggregates
    if(isAggregateC(cursor) && cursor.spelling == "")
        return true;

    static immutable forbiddenSpellings =
        [
            "ulong", "ushort", "uint",
            "va_list", "__gnuc_va_list",
            "_IO_2_1_stdin_", "_IO_2_1_stdout_", "_IO_2_1_stderr_",
        ];

    return forbiddenSpellings.canFind(cursor.spelling) ||
        cursor.isPredefined ||
        cursor.kind == Cursor.Kind.MacroExpansion
        ;
}


string[] translate(in from!"clang".Cursor cursor,
                   ref from!"dpp.runtime.context".Context context,
                   in string file = __FILE__,
                   in size_t line = __LINE__)
    @safe
{
    import std.conv: text;

    debugCursor(cursor, context);

    if(cursor.kind !in translators)
        throw new Exception(text("Cannot translate unknown cursor kind ", cursor.kind),
                            file,
                            line);

    const indentation = context.indentation;
    scope(exit) context.setIndentation(indentation);
    context.indent;

    try
        return translators[cursor.kind](cursor, context);
    catch(Exception e) {
        import std.stdio: stderr;
        debug {
            () @trusted {
                stderr.writeln("\nCould not translate cursor ", cursor,
                               " sourceRange: ", cursor.sourceRange,
                               " children: ", cursor.children, "\n");
            }();
        }
        throw e;
    }
}

void debugCursor(in from!"clang".Cursor cursor,
                 in from!"dpp.runtime.context".Context context)
    @safe
{
    import clang: Cursor;
    import std.algorithm: startsWith, canFind;

    version(unittest) {}
    else if(!context.debugOutput) return;

    const isMacro = cursor.kind == Cursor.Kind.MacroDefinition;
    const isOkMacro =
        !cursor.spelling.startsWith("__") &&
        !["_LP64", "unix", "linux"].canFind(cursor.spelling);
    const canonical = cursor.isCanonical ? " CAN" : "";
    const definition = cursor.isDefinition ? " DEF" : "";

    if(!isMacro || isOkMacro) {
        context.log(cursor, canonical, definition, " @ ", cursor.sourceRange);
    }
}

Translator[from!"clang".Cursor.Kind] translators() @safe {
    import dpp.cursor;
    import clang: Cursor;
    import dpp.expansion: expand;

    static string[] ignore(
        in Cursor cursor,
        ref from!"dpp.runtime.context".Context context)
    {
        return [];
    }

    static string[] translateUnexposed(
        in Cursor cursor,
        ref from!"dpp.runtime.context".Context context)
    {
        import clang: Type;
        import std.conv: text;

        switch(cursor.type.kind) with(Type.Kind) {
            default:
                throw new Exception(text("Unknown unexposed declaration type ", cursor.type));
            case Invalid:
                return [];
        }
        assert(0);
    }

    static string[] translateAccess(
        in Cursor cursor,
        ref from!"dpp.runtime.context".Context context)
    {
        import clang: AccessSpecifier;

        final switch(cursor.accessSpecifier) with(AccessSpecifier) {
            case InvalidAccessSpecifier: assert(0);
            case Public: return ["public:"];
            case Protected: return ["protected:"];
            case Private: return ["private:"];
        }

        assert(0);
    }

    with(Cursor.Kind) {
        return [
            ClassDecl:                &translateClass,
            StructDecl:               &translateStruct,
            UnionDecl:                &translateUnion,
            EnumDecl:                 &translateEnum,
            FunctionDecl:             &translateFunction,
            FieldDecl:                &translateField,
            TypedefDecl:              &translateTypedef,
            MacroDefinition:          &translateMacro,
            InclusionDirective:       &ignore,
            EnumConstantDecl:         &translateEnumConstant,
            VarDecl:                  &translateVariable,
            UnexposedDecl:            &translateUnexposed,
            CXXAccessSpecifier:       &translateAccess,
            CXXMethod:                &translateFunction,
            Constructor:              &translateFunction,
            Destructor:               &translateFunction,
            TypeAliasDecl:            &translateTypedef,
            ClassTemplate:            &translateClass,
            TemplateTypeParameter:    &ignore,
            NonTypeTemplateParameter: &ignore,
            ConversionFunction:       &translateFunction,
        ];
    }
}
