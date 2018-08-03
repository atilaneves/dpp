module dpp2.translation.type;

import dpp.from;

string translate(from!"dpp2.type".Type type) @safe pure {
    import dpp2.type;
    import sumtype: match;
    import std.conv: text;

    return type.match!(
        (Void _) => "void",
        (NullPointerT _) => "void*",
        (Bool _) => "bool",
        (UnsignedChar _) => "ubyte",
        (SignedChar _) => "byte",
        (Char _) => "char",
        (Wchar _) => translateWchar(),
        (Char16 _) => "wchar",
        (Char32 _) => "dchar",
        (Short _) => "short",
        (UnsignedShort _) => "ushort",
        (Int _) => "int",
        (UnsignedInt _) => "uint",
        (Long _) => "c_long",
        (UnsignedLong _) => "c_ulong",
        (LongLong _) => "long",
        (UnsignedLongLong _) => "ulong",
        (Float _) => "float",
        (Double _) => "double",
        (LongDouble _) => "real",
        (Pointer ptr) => text(translate(*ptr.pointeeType), "*"),
        (ConstantArray arr) => text(translate(*arr.elementType), "[", arr.length, "]"),
    );
}


private string translateWchar() @safe pure {
    version(Windows)
        return "wchar";
    else
        return "dchar";
}
