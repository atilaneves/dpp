/**
   From clang's cursors to dpp's nodes.
 */
module dpp2.transform;


import dpp.from;


from!"dpp2.sea.node".Node toNode(in from!"clang".Cursor cursor) @safe {
    import dpp2.sea.node;
    import dpp2.sea.type;
    static import clang;
    import std.algorithm: map;
    import std.array: array;

    return Node(
        Struct(
            cursor.spelling,
            cursor.children.map!(c => Field(toType(c.type), c.spelling)).array
        )
    );
}


from!"dpp2.sea.type".Type toType(in from!"clang".Type clangType) @safe pure {
    import dpp2.sea.type;
    static import clang;
    import std.conv: text;
    import std.array: replace;

    alias Kind = clangType.Kind;

    switch(clangType.kind) {

        default:
            throw new Exception(text("Unknown type kind: ", clangType));

        case Kind.Void: return Type(Void());
        case Kind.NullPtr: return Type(NullPointerT());
        case Kind.Bool: return Type(Bool());

        case Kind.WChar: return Type(Wchar());
        case Kind.SChar: return Type(SignedChar());
        case Kind.Char16: return Type(Char16());
        case Kind.Char32: return Type(Char32());
        case Kind.UChar: return Type(UnsignedChar());
        case Kind.Char_U: return Type(UnsignedChar());
        case Kind.Char_S: return Type(SignedChar());

        case Kind.UShort: return Type(UnsignedShort());
        case Kind.Short: return Type(Short());
        case Kind.Int: return Type(Int());
        case Kind.UInt: return Type(UnsignedInt());
        case Kind.Long: return Type(Long());
        case Kind.ULong: return Type(UnsignedLong());
        case Kind.LongLong: return Type(LongLong());
        case Kind.ULongLong: return Type(UnsignedLongLong());
        case Kind.Int128: return Type(Int128());
        case Kind.UInt128: return Type(UnsignedInt128());

        case Kind.Half: return Type(Half());
        case Kind.Float: return Type(Float());
        case Kind.Double: return Type(Double());
        case Kind.LongDouble: return Type(LongDouble());
        case Kind.Float128: return Type(LongDouble());

        case Kind.Record: return Type(UserDefinedType(clangType.spelling));
        case Kind.Elaborated:
            return Type(UserDefinedType(clangType.spelling
                                        .replace("struct ", "")
                                        .replace("union ", "")
                                        .replace("enum ", "")));
    }
}
