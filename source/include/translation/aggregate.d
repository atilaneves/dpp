/**
   Translate aggregates
 */
module include.translation.aggregate;

import include.from;

string[] translateAggregate(
    in from!"clang".Cursor cursor,
    in string keyword,
    string function(in from!"clang".Cursor) @safe translation
)
    @safe
{
    import clang: Cursor;

    string[] ret;

    ret ~= keyword ~ ` ` ~ cursor.spelling;
    ret ~= `{`;
    foreach(member; cursor) {
        ret ~= translation(member);
    }
    ret ~= `}`;

    return ret;
}
