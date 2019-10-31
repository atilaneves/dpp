/**
   Cursor translations
 */
module dpp.translation.translation;

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

    return skipTopLevel(cursor, context)
        ? ""
        : translate(cursor, context, file, line).map!(a => "    " ~ a).join("\n");
}

private bool skipTopLevel(in from!"clang".Cursor cursor,
                          in from!"dpp.runtime.context".Context context)
    @safe
{
    import dpp.translation.aggregate: isAggregateC;
    import clang: Cursor;
    import std.algorithm: startsWith, canFind;

    if(context.isFromIgnoredPath(cursor))
        return true;

    // We want to ignore anonymous structs and unions but not enums. See #54
    if(cursor.spelling == "" && cursor.kind == Cursor.Kind.EnumDecl)
        return false;

    // don't bother translating top-level anonymous aggregates
    if(isAggregateC(cursor) && cursor.spelling == "")
        return true;

    if(context.options.ignoreMacros && cursor.kind == Cursor.Kind.MacroDefinition)
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
    import dpp.runtime.context: Language;
    import dpp.translation.exception: UntranslatableException;
    import std.conv: text;
    import std.algorithm: canFind, any;
    import std.array: join;

    debugCursor(cursor, context);

    if(context.language == Language.Cpp && ignoredCppCursorSpellings.canFind(cursor.spelling)) {
        return [];
    }

    if(context.options.ignoredCursors.canFind(cursor.spelling)) {
        return [];
    }

    if(cursor.kind !in translators) {
        if(context.options.hardFail)
            throw new Exception(text("Cannot translate unknown cursor kind ", cursor.kind),
                                file,
                                line);
        else
            return [];
    }

    const indentation = context.indentation;
    scope(exit) context.setIndentation(indentation);
    context.indent;

    try {
        auto lines = translators[cursor.kind](cursor, context);

        if(lines.any!untranslatable)
            throw new UntranslatableException(
                text("Not valid D:\n",
                     "------------\n",
                     lines.join("\n"),
                    "\n------------\n",));

        return lines;
    } catch(UntranslatableException e) {

        debug {
            import std.stdio: stderr;
            () @trusted {
                if(context.options.detailedUntranslatable)
                    stderr.writeln("\nUntranslatable cursor ", cursor,
                                   "\nmsg: ", e.msg,
                                   "\nsourceRange: ", cursor.sourceRange,
                                   "\nchildren: ", cursor.children,
                                   "\n");
                else
                    stderr.writeln("Untranslatable cursor ", cursor);
            }();
        }

        if(context.options.hardFail)
            throw e;
        else
            return [];

    } catch(Exception e) {

        debug {
            import std.stdio: stderr;
            () @trusted {
                stderr.writeln("\nCould not translate cursor ", cursor,
                               "\nmsg: ", e.msg,
                               "\nsourceRange: ", cursor.sourceRange,
                               "\nchildren: ", cursor.children, "\n");
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
        !cursor.spelling.startsWith("_GLIBCXX") &&
        !["_LP64", "unix", "linux"].canFind(cursor.spelling);
    const canonical = cursor.isCanonical ? " CAN" : "";
    const definition = cursor.isDefinition ? " DEF" : "";

    if(!isMacro || isOkMacro) {
        context.log(cursor, canonical, definition, " @ ", cursor.sourceRange);
    }
}


Translator[from!"clang".Cursor.Kind] translators() @safe {
    static Translator[from!"clang".Cursor.Kind] ret;
    if(ret == ret.init) ret = translatorsImpl;
    return ret;
}


private Translator[from!"clang".Cursor.Kind] translatorsImpl() @safe pure {
    import dpp.translation;
    import clang: Cursor;

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

        context.accessSpecifier = cursor.accessSpecifier;

        final switch(cursor.accessSpecifier) with(AccessSpecifier) {
            case InvalidAccessSpecifier: assert(0);
            case Public: return ["    public:"];
            case Protected: return ["    protected:"];
            case Private: return ["    private:"];
        }

        assert(0);
    }

    with(Cursor.Kind) {
        return [
            ClassDecl:                          &translateClass,
            StructDecl:                         &translateStruct,
            UnionDecl:                          &translateUnion,
            EnumDecl:                           &translateEnum,
            FunctionDecl:                       &translateFunction,
            FieldDecl:                          &translateField,
            TypedefDecl:                        &translateTypedef,
            MacroDefinition:                    &translateMacro,
            InclusionDirective:                 &translateInclude,
            EnumConstantDecl:                   &translateEnumConstant,
            VarDecl:                            &translateVariable,
            UnexposedDecl:                      &translateUnexposed,
            CXXAccessSpecifier:                 &translateAccess,
            CXXMethod:                          &translateFunction,
            Constructor:                        &translateFunction,
            Destructor:                         &translateFunction,
            TypeAliasDecl:                      &translateTypedef,
            ClassTemplate:                      &translateClass,
            TemplateTypeParameter:              &ignore,
            NonTypeTemplateParameter:           &ignore,
            ConversionFunction:                 &translateFunction,
            Namespace:                          &translateNamespace,
            VisibilityAttr:                     &ignore, // ???
            // FirstAttr appears when there are compiler-specific attributes on a type
            FirstAttr:                          &ignore,
            ClassTemplatePartialSpecialization: &translateClass,
            TypeAliasTemplateDecl:              &translateTypeAliasTemplate,
            FunctionTemplate:                   &translateFunction,
            // For ParmDecl, see it.cpp.opaque.std::function
            ParmDecl:                           &ignore,
            CXXBaseSpecifier:                   &ignore,
            UsingDeclaration:                   &translateInheritingConstructor,
        ];
    }
}

string[] translateInclude(in from!"clang".Cursor cursor,
                          ref from!"dpp.runtime.context".Context context)
    @safe
{
    if(auto ptr = cursor.spelling in context.options.prebuiltHeaders)
        return ["import " ~ *ptr ~ ";"];
    return null;
}

// if this translated line can't be valid D code
bool untranslatable(in string line) @safe pure {
    import std.algorithm: canFind;
    return
        line.canFind(`&)`)
        || line.canFind("&,")
        || line.canFind("&...")
        || line.canFind(" (*)")
        || line.canFind("variant!")
        || line.canFind("value _ ")
        || line.canFind("enable_if_c")
        || line.canFind(`(this_)_M_t._M_equal_range_tr(`)
        || line.canFind(`this-`)
        || line.canFind("_BoundArgs...")
        || line.canFind("sizeof...")
        || line.canFind("template<")  // FIXME: mir_slice
        ;
}


// blacklist of cursors in the C++ standard library that dpp can't handle
private string[] ignoredCppCursorSpellings() @safe pure nothrow {
    return
        [
            "is_function",  // dmd bug
            "is_const",
            "is_volatile",
            "allocator_traits",  // FIXME
            "pair",  // FIXME
            "underlying_type",
            "underlying_type_t",
            "result_of",
            "result_of_t",
            "pointer_traits", // FIXME
            "iterator_traits",  // FIXME
            "piecewise_construct", // FIXME
            "is_rvalue_reference",
            "remove_reference",
            "remove_reference_t",
            "remove_extent",  // FIXME
            "remove_extent_t",  // FIXME
            "remove_all_extents",  // FIXME
            "remove_all_extents_t",  // FIXME

            // derives from std::iterator, which is untranslatable due to it taking a
            // reference template parameter
            "_Bit_iterator_base",
            "_Bit_iterator",
            "_Bit_const_iterator",
            // needs _Bit_iterator and co
            "_Bvector_base",
        ];
}
