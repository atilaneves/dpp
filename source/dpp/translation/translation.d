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
                stderr.writeln("\nUntranslatable cursor ", cursor,
                               "\nmsg: ", e.msg,
                               "\nsourceRange: ", cursor.sourceRange,
                               "\nchildren: ", cursor.children, "\n");
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
            InclusionDirective:                 &ignore,
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
            FirstAttr:                          &ignore, // ???
            ClassTemplatePartialSpecialization: &translateClass,
            CXXBaseSpecifier:                   &translateBase,
            TypeAliasTemplateDecl:              &translateTypeAliasTemplate,
            FunctionTemplate:                   &translateFunction,
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
        || line.canFind(`}))`)
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

            // xenon / boost / STL
            "optional", // FIXME
            "is_variant_constructible_from", // FIXME
            "invoke_visitor",  // FIXME
            "make_variant_list",  // FIXME
            "has_result_type",  // FIXME
            "apply_visitor_binary_invoke", // FIXME
            "apply_visitor_binary_unwrap", // FIXME
            "is_assignable_imp",  // FIXME
            "has_trivial_constructor",  // FIXME
            "has_trivial_default_constructor",  // FIXME
            "has_trivial_destructor",  // FIXME
            "has_nothrow_constructor",  // FIXME
            "has_trivial_copy",  // FIXME
            "type_with_alignment",  // FIXME
            "ct_imp",  // FIXME
            "is_constructible_imp",  // FIXME
            "is_destructible_imp",  // FIXME
            "is_default_constructible_imp",  // FIXME
            "aligned_storage_impl",  // FIXME
            "aligned_struct_wrapper",  // FIXME
            "has_nothrow_copy_constructor",  // FIXME
            "is_constructible",  // FIXME
            "is_default_constructible",  // FIXME
            "hash_combine_tuple",  // FIXME
            "is_character_type",  // FIXME
            "strictest_lock_impl",
            "strictest_lock",
            "light_function",  // FIXME
            "inherit_features",  // FIXME
            "addr_impl_ref",  // FIXME
            "_Hashtable_ebo_helper",  // FIXME
            "unordered_multimap",  // FIXME'
            "unordered_map",  // FIXME STL
            "is_string_widening_required_t",  // FIXME
            "is_arithmetic_and_not_xchars",  // FIXME
            "is_xchar_to_xchar",  // FIXME
            "date_facet",  // FIXME
            "date_input_facet",  // FIXME
            "date_generator_formatter",  // FIXME
            "int_t",  // FIXME
            "uint_t", // FIXME
            "int_max_value_t",  // FIXME
            "int_min_value_t",  // FIXME
            "uint_value_t",  // FIXME
            "precision",  // FIXME
            "append_N",  // FIXME
            "normalise",  // FIXME
            "evaluation",  // FIXME
            "plus_impl",  // FIXME
            "minus_impl",  // FIXME
            "advance_forward",  // FIXME
            "advance_backward", // FIXME
            "not_equal_to_impl",  // FIXME
            "greater_impl",  // FIXME
            "iter_fold_impl",  // FIXME
            "less_equal_impl",  // FIXME
            "special_values_formatter",  // FIXME
            "period_formatter",  // FIXME
            "assert",  // FIXME - should be caught by dpp.translation.dlang
            "assertion_failed",
            "multimap", // FIXME STL
            "map",  // FIXME STL
            "function",  // FIXME - should be caught by dpp.translation.dlang
            "_Function_handler",  // FIXME
            "_Mem_fn",  // FIXME
            "mem_fn",  // FIXME STL
            "_Mu",  // FIXME - C cast
            "__volget",  // FIXME
            "_Bind",  // FIXME
            "_Bind_result", // FIXME
            "_Bind_check_arity",  // FIXME
            "_Bind_helper",  // FIXME
            "_Not_fn",  // FIXME
            "__is_byte_like", // FIXME
            "shared_ptr",  // FIXME STL
            "weak_ptr",  // FIXME STL
            "_Sp_ebo_helper",  // FIXME STL
            "auto_ptr",  // FIXME STL
            "__allocated_ptr",  // FIXME STL
            "tuple_size",  // FIXME STL
            "__invoke",  // FIXME
            "_Mem_fn_traits",  // FIXME
            "_Weak_result_type_impl", // FIXME
            "__uses_alloc",  // FIXME
            "_Tuple_impl", // FIXME
            "_TC",  // FIXME
            "__combine_tuples",  // FIXME
            "__tuple_concater",  // FIXME
            "tuple_cat",  // FIXME STL
            "reference_wrapper",
            "tuple",  // FIXME STL
            "__is_copy_insertable_impl", // FIXME
            "greater",  // FIXME STL
            "less",  // FIXME STL
            "greater_equal",  // FIXME STL
            "less_equal",  // FIXME STL
            "logical_and", // FIXME STL
            "mir_rci",  // FIXME
        ];
}
