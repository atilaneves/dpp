module ut.transform.type;


import ut.transform;
import dpp2.transform: toType;
import clang: ClangType = Type;

alias Kind = ClangType.Kind;


@("void")
@safe pure unittest {
    ClangType(Kind.Void).toType.should == Type(Void());
}


@("nullptr")
@safe pure unittest {
    ClangType(Kind.NullPtr).toType.should == Type(NullPointerT());
}


@("bool")
@safe pure unittest {
    ClangType(Kind.Bool).toType.should == Type(Bool());
}


@("wchar")
@safe pure unittest {
    ClangType(Kind.WChar).toType.should == Type(Wchar());
}


@("schar")
@safe pure unittest {
    ClangType(Kind.SChar).toType.should == Type(SignedChar());
}


@("char16")
@safe pure unittest {
    ClangType(Kind.Char16).toType.should == Type(Char16());
}


@("char32")
@safe pure unittest {
    ClangType(Kind.Char32).toType.should == Type(Char32());
}


@("uchar")
@safe pure unittest {
    ClangType(Kind.UChar).toType.should == Type(UnsignedChar());
}


@("char_u")
@safe pure unittest {
    ClangType(Kind.Char_U).toType.should == Type(UnsignedChar());
}


@("char_s")
@safe pure unittest {
    ClangType(Kind.Char_S).toType.should == Type(SignedChar());
}


@("ushort")
@safe pure unittest {
    ClangType(Kind.UShort).toType.should == Type(UnsignedShort());
}


@("short")
@safe pure unittest {
    ClangType(Kind.Short).toType.should == Type(Short());
}


@("int")
@safe pure unittest {
    ClangType(Kind.Int).toType.should == Type(Int());
}


@("uint")
@safe pure unittest {
    ClangType(Kind.UInt).toType.should == Type(UnsignedInt());
}


@("long")
@safe pure unittest {
    ClangType(Kind.Long).toType.should == Type(Long());
}


@("ulong")
@safe pure unittest {
    ClangType(Kind.ULong).toType.should == Type(UnsignedLong());
}


@("longlong")
@safe pure unittest {
    ClangType(Kind.LongLong).toType.should == Type(LongLong());
}


@("ulonglong")
@safe pure unittest {
    ClangType(Kind.ULongLong).toType.should == Type(UnsignedLongLong());
}


@("int128")
@safe pure unittest {
    ClangType(Kind.Int128).toType.should == Type(Int128());
}


@("uint128")
@safe pure unittest {
    ClangType(Kind.UInt128).toType.should == Type(UnsignedInt128());
}


@("float")
@safe pure unittest {
    ClangType(Kind.Float).toType.should == Type(Float());
}


@("double")
@safe pure unittest {
    ClangType(Kind.Double).toType.should == Type(Double());
}


@("float128")
@safe pure unittest {
    ClangType(Kind.Float128).toType.should == Type(LongDouble());
}


@("half")
@safe pure unittest {
    ClangType(Kind.Half).toType.should == Type(Half());
}


@("longdouble")
@safe pure unittest {
    ClangType(Kind.LongDouble).toType.should == Type(LongDouble());
}


@("record")
@safe pure unittest {
    ClangType(Kind.Record, "mytype").toType.should == Type(UserDefinedType("mytype"));
}
