/**
   union translations
 */
module include.translation.union_;

import include.from;

string[] translateUnion(in from!"clang".Cursor union_) @safe {
    import include.translation.aggregate: translateAggregate;
    return translateAggregate(union_, "union");
}
