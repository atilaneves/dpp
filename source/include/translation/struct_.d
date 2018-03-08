/**
   Struct translations.
 */
module include.translation.struct_;

import include.from;

string[] translateStruct(in from!"clang".Cursor struct_) @safe {
    import include.translation.aggregate: translateAggregate;
    return translateAggregate(struct_, "struct");
}
