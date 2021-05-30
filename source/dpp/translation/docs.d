module dpp.translation.docs;

import dpp.from;

/** Get the attached comments at the location of the cursor */
string get_comment(in from!"clang".Cursor cursor, bool breakln = true) @safe {
    import std.typecons: Nullable;
    string docStr = "";
    Nullable!string nullableComment = cursor.raw_comment();
    if(!nullableComment.isNull) {
        docStr = nullableComment.get();
        if (breakln) {
            docStr ~= "\n    ";
        }
    }
    return docStr;
}
