module dpp2.translation.type;

import dpp.from;

string translate(from!"dpp2.type".Type type) @safe pure {
    import dpp2.type;
    import sumtype: match;
    import std.conv: text;

    return type.match!(
        (Void _) => "void",
        (Int i) => "int",
        (Long l) => "c_long",
        (ConstantArray ca) => text(translate(*ca.elementType), "[", ca.length, "]"),
    );
}
