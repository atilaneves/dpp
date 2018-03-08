module include.translation.typedef_;

import include.from;

string[] translateTypedef(in from!"clang".Cursor typedef_) @safe {

    string[] ret;

    foreach(member; typedef_) {
        ret ~= `alias ` ~ typedef_.spelling ~ ` = ` ~ member.spelling  ~ `;`;
    }

    return ret;
}
