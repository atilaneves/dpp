/**
   Translate aggregates
 */
module include.translation.aggregate;

import include.from;

string[] translateAggregate(
    in from!"clang".Cursor cursor,
    in string keyword,
    string function(in from!"clang".Cursor) @safe translation,
)
    @safe
{
    import clang: Cursor;

    string[] lines;

    lines ~= keyword ~ ` ` ~ cursor.spelling;
    lines ~= `{`;

    foreach(member; cursor) {
        lines ~= "    " ~ translation(member);
    }

    lines ~= `}`;

    return lines;
}
