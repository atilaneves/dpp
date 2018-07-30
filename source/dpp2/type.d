module dpp2.type;

import dpp.from;

alias Type = from!"dpp2.sum".Sum!(
    Void, NullPointerT,
    Bool,
    UnsignedChar, SignedChar, Char, Wchar, Char16, Char32,
    Short, UnsignedShort, Int, UnsignedInt, Long, UnsignedLong, LongLong, UnsignedLongLong,
    Float, Double, LongDouble,
    Pointer,
    ConstantArray,
);

struct Void {}
struct NullPointerT {}
struct Bool {}
struct UnsignedChar {}
struct SignedChar {}
struct Char {}
struct Wchar {}
struct Char16 {}
struct Char32 {}
struct Short {}
struct UnsignedShort {}
struct Int {}
struct UnsignedInt {}
struct Long {}
struct UnsignedLong {}
struct LongLong {}
struct UnsignedLongLong {}
struct Float {}
struct Double {}
struct LongDouble {}

struct Pointer {
    Type* pointeeType;
}

struct ConstantArray {
    Type* elementType;
    int length;
}
