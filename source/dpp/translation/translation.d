/**
   Cursor translations
 */
module dpp.translation.translation;


import dpp.from;


alias Translator = string[] function(
    in from!"dpp.ast.node".Node node,
    ref from!"dpp.runtime.context".Context context,
) @safe;


string translateTopLevel(in from!"dpp.ast.node".Node node,
                         ref from!"dpp.runtime.context".Context context,
                         in string file = __FILE__,
                         in size_t line = __LINE__)
    @safe
{
    import std.array: join;
    import std.algorithm: map;

    return skipTopLevel(node, context)
        ? ""
        : translate(node, context, file, line).map!(a => "    " ~ a).join("\n");
}

private bool skipTopLevel(in from!"clang".Cursor cursor,
                          in from!"dpp.runtime.context".Context context)
    @safe pure
{
    import dpp.translation.aggregate: isAggregateC;
    import clang: Cursor;
    import std.algorithm: startsWith, canFind;

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


string[] translate(in from!"dpp.ast.node".Node node,
                   ref from!"dpp.runtime.context".Context context,
                   in string file = __FILE__,
                   in size_t line = __LINE__)
    @safe
{
    import dpp.runtime.context: Language;
    import dpp.translation.exception: UntranslatableException;
    import dpp.ast.node: Node;
    import std.conv: text;
    import std.algorithm: canFind, any;
    import std.array: join;

    debugCursor(node, context);

    if(context.language == Language.Cpp && ignoredCppCursorSpellings.canFind(node.spelling)) {
        return [];
    }

    if(context.options.ignoredCursors.canFind(node.spelling)) {
        return [];
    }

    if(node.kind !in translators) {
        if(context.options.hardFail)
            throw new Exception(text("Cannot translate unknown cursor kind ", node.kind),
                                file,
                                line);
        else
            return [];
    }

    const indentation = context.indentation;
    scope(exit) context.setIndentation(indentation);
    context.indent;

    try {
        auto lines = translators[node.kind](node, context);

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
                    stderr.writeln("\nUntranslatable cursor ", node.cursor,
                                   "\nmsg: ", e.msg,
                                   "\nsourceRange: ", node.sourceRange,
                                   "\nchildren: ", node.children, "\n");
                else
                    stderr.writeln("Untranslatable cursor ", node.cursor);
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
                stderr.writeln("\nCould not translate cursor ", node.cursor,
                               "\nmsg: ", e.msg,
                               "\nsourceRange: ", node.sourceRange,
                               "\nchildren: ", node.children, "\n");
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
    import dpp.translation;
    import dpp.ast.node: Node;
    import clang: Cursor;

    static string[] ignore(
        in Node node,
        ref from!"dpp.runtime.context".Context context)
    {
        return [];
    }

    static string[] translateUnexposed(
        in Node node,
        ref from!"dpp.runtime.context".Context context)
    {
        import clang: Type;
        import std.conv: text;

        switch(node.type.kind) with(Type.Kind) {
            default:
                throw new Exception(text("Unknown unexposed declaration type ", node.type));
            case Invalid:
                return [];
        }
        assert(0);
    }

    static string[] translateAccess(
        in Node node,
        ref from!"dpp.runtime.context".Context context)
    {
        import clang: AccessSpecifier;

        context.accessSpecifier = node.accessSpecifier;

        final switch(node.accessSpecifier) with(AccessSpecifier) {
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
            FieldDecl:                          &translateField,
            FunctionDecl:                       &translateFunction,
            CXXMethod:                          &translateFunction,
            Constructor:                        &translateFunction,
            Destructor:                         &translateFunction,
            ConversionFunction:                 &translateFunction,
            FunctionTemplate:                   &translateFunction,
            TypedefDecl:                        &translateTypedef,
            MacroDefinition:                    &translateMacro,
            InclusionDirective:                 &ignore,
            EnumConstantDecl:                   &translateEnumConstant,
            VarDecl:                            &translateVariable,
            UnexposedDecl:                      &translateUnexposed,
            CXXAccessSpecifier:                 &translateAccess,
            TypeAliasDecl:                      &translateTypedef,
            ClassTemplate:                      &translateClass,
            TemplateTypeParameter:              &ignore,
            NonTypeTemplateParameter:           &ignore,
            Namespace:                          &translateNamespace,
            VisibilityAttr:                     &ignore, // ???
            FirstAttr:                          &ignore, // ???
            ClassTemplatePartialSpecialization: &translateClass,
            TypeAliasTemplateDecl:              &translateTypeAliasTemplate,
        ];
    }
}

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
        || line.canFind(`}))`)  // ???
        || line.canFind(`(this_)_M_t._M_equal_range_tr(`)
        || line.canFind(`this-`)
        || line.canFind("function!")
        || line.canFind("_BoundArgs...")
        || line.canFind("sizeof...")
        || line.canFind("template<")  // FIXME: mir_slice
        ;
}


// blacklist of cursors in the C++ standard library that dpp can't handle
string[] ignoredCppCursorSpellings() @safe pure nothrow {
    return
        [
            "is_function",  // dmd bug
            "__is_referenceable",
            "__is_convertible_helper",
            "aligned_union",
            "aligned_union_t",
            "__expanded_common_type_wrapper",
            "underlying_type",
            "underlying_type_t",
            "__result_of_memfun_ref",
            "__result_of_memfun_deref",
            "__result_of_memfun",
            "__result_of_impl",
            "result_of",
            "result_of_t",
            "__detector",
            "__detected_or",
            "__detected_or_t",
            "__is_swappable_with_impl",
            "__is_nothrow_swappable_with_impl",
            "is_rvalue_reference",
            "__is_member_pointer_helper",
            "__do_is_implicitly_default_constructible_impl",
            "remove_reference",
            "remove_reference_t",
            "remove_extent",  // FIXME
            "remove_extent_t",  // FIXME
            "remove_all_extents",  // FIXME
            "remove_all_extents_t",  // FIXME
            "__remove_pointer_helper", // FIXME
            "__result_of_memobj",
            "piecewise_construct_t",  // FIXME (@disable ctor)
            "piecewise_construct",  // FIXME (piecewise_construct_t)

            "hash", // FIXME (stl_bvector.h partial template specialisation)
            "__is_fast_hash",  // FIXME (hash)

            "move_iterator",  // FIXME (extra type parameters)
            "__replace_first_arg", // FIXME
            "pointer_traits", // FIXME
            "pair",  // FIXME
            "iterator_traits",  // FIXME

            "_Hash_bytes",  // FIXME (std.size_t)
            "_Fnv_hash_bytes", // FIXME (std.size_t)
            "allocator_traits",  // FIXME
            "__allocator_traits_base",  // FIXME
            "__is_signed_helper",  // FIXME - inheritance
            "__is_array_known_bounds",  // FIXME - inheritance
            "__is_copy_constructible_impl",  // FIXME - inheritance
            "__is_nothrow_copy_constructible_impl",  // FIXME - inheritance
            "__is_copy_assignable_impl",  // FIXME - inheritance
            "__is_move_assignable_impl",  // FIXME - inheritance
            "__is_nt_copy_assignable_impl",  // FIXME - inheritance
            "__is_nt_move_assignable_impl",  // FIXME - inheritance
            "extent",  // FIXME - inheritance
            "move_if_noexcept",
            "__do_is_destructible_impl",  // FIXME
            "__do_is_nt_destructible_impl",  // FIXME
            "__do_is_default_constructible_impl",  // FIXME
            "__result_of_memfun_ref_impl",  // FIXME
            "__result_of_memfun_deref_impl",   // FIXME
            "__result_of_memobj_ref_impl",
            "__result_of_memobj_deref_impl",
            "__result_of_other_impl",
            "__do_is_swappable_impl",
            "__do_is_nothrow_swappable_impl",
            "is_optional_val_init_candidate",
        ];
}
