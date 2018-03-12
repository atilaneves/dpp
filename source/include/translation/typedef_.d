module include.translation.typedef_;

import include.from;

string[] translateTypedef(in from!"clang".Cursor typedef_) @safe {

    import include.translation.aggregate: spellingOrNickname;
    import std.conv: text;

    string[] ret;

    foreach(member; typedef_) {
        ret ~= `alias ` ~ typedef_.spelling ~ ` = ` ~ spellingOrNickname(member)  ~ `;`;
    }

    assert(ret.length == 1, text("typedefs should only have 1 member, not ", ret.length));

    return ret;
}
