/**
   From clang's cursors to dpp's nodes.
 */
module dpp2.transform;


import dpp.from;


/**
   Transforms a clang `Cursor` (or a mock) into a dpp `Node`
 */
from!"dpp2.sea.node".Node[] toNode(C)(in C cursor) @trusted {

    import std.traits: isPointer;
    import std.conv: text;

    static if(isPointer!C)
        const cursorText = text(*cursor, " def? ", cursor.isDefinition);
    else
        const cursorText = text( cursor, " def? ", cursor.isDefinition);

    version(unittest) {
        import unit_threaded;
        () @trusted { writelnUt("toNode cursor: ", cursorText); }();
    }

    auto transform = cursor.kind in transformations!C;

    if(transform is null)
        throw new Exception("Unknown cursor kind: " ~ cursorText);

    return (*transform)(cursor);
}

auto transformations(C)() {
    import clang: Cursor;
    with(Cursor.Kind) {
        return [
            TranslationUnit: &fromTranslationUnit!C,
            StructDecl: &fromStruct!C,
            FieldDecl: &fromField!C,
            TypedefDecl: &fromTypedef!C,
        ];
    }
}

from!"dpp2.sea.node".Node[] fromTranslationUnit(C)(in C cursor) @trusted
    in(cursor.kind == from!"clang".Cursor.Kind.TranslationUnit)
do
{
    import std.algorithm: filter, map;
    import std.array: join;

    auto cursors = cursor.children
        .filter!(a => a.isDefinition)
        ;

    return cursors.map!(c => toNode(c)).join;
}


from!"dpp2.sea.node".Node[] fromStruct(C)(in C cursor) @trusted
    in(cursor.kind == from!"clang".Cursor.Kind.StructDecl)
do
{
    import dpp2.sea.node: Node, Struct;
    import std.algorithm: map;
    import std.array: join;

    return [
        Node(
            Struct(cursor.spelling,
                   cursor.children.map!(c => toNode(c)).join,
                   cursor.type.spelling),
        )
    ];
}



from!"dpp2.sea.node".Node[] fromField(C)(in C cursor) @trusted
    in(cursor.kind == from!"clang".Cursor.Kind.FieldDecl)
do
{
    import dpp2.sea.node: Node, Field;
    return [Node(Field(toType(cursor.type), cursor.spelling))];
}


from!"dpp2.sea.node".Node[] fromTypedef(C)(in C cursor) @trusted
    in(cursor.kind == from!"clang".Cursor.Kind.TypedefDecl)
do
{
    import dpp2.sea.node: Node, Typedef;
    return [Node(Typedef(cursor.spelling, cursor.underlyingType.toType))];
}


from!"dpp2.sea.type".Type toType(T)(in T clangType) @safe {
    import dpp2.sea.type;
    import std.conv: text;

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

        case Kind.Record:
        case Kind.Elaborated:  // FIXME (could be enum or union)
            return Type(UserDefinedType(clangType.spelling.unelaborate));
    }
}


private string unelaborate(in string spelling) @safe pure {
    import std.array: replace;
    return spelling
        .replace("struct ", "")
        .replace("union ", "")
        .replace("enum ", "")
        ;
}
