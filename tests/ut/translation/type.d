module ut.translation.type;

import ut.translation;
import include.translation.type;
import clang: Type;


@("void")
@safe pure unittest {
    Type(Type.Kind.Void).translate.shouldEqual("void");
}

@("bool")
@safe pure unittest {
    Type(Type.Kind.Bool).translate.shouldEqual("bool");
}

@("char_u")
@safe pure unittest {
    Type(Type.Kind.Char_U).translate.shouldEqual("ubyte");
}

@("UChar")
@safe pure unittest {
    Type(Type.Kind.UChar).translate.shouldEqual("ubyte");
}

@("Char16")
@safe pure unittest {
    Type(Type.Kind.Char16).translate.shouldEqual("wchar");
}

@("Char32")
@safe pure unittest {
    Type(Type.Kind.Char32).translate.shouldEqual("dchar");
}

@("unsigned short")
@safe pure unittest {
    Type(Type.Kind.UShort).translate.shouldEqual("ushort");
}

@("unsigned int")
@safe pure unittest {
    Type(Type.Kind.UInt).translate.shouldEqual("uint");
}

@("unsigned long")
@safe pure unittest {
    version(Windows)
        Type(Type.Kind.ULong).translate.shouldEqual("uint");
    else
        Type(Type.Kind.ULong).translate.shouldEqual("ulong");
}

@("unsigned long long")
@safe pure unittest {
    Type(Type.Kind.ULongLong).translate.shouldEqual("ulong");
}

@("uint128")
@safe pure unittest {
    Type(Type.Kind.UInt128).translate.shouldEqual("ucent");
}

@("char_s")
@safe pure unittest {
    Type(Type.Kind.Char_S).translate.shouldEqual("byte");
}

@("SChar")
@safe pure unittest {
    Type(Type.Kind.SChar).translate.shouldEqual("byte");
}

@("WChar")
@safe pure unittest {
    Type(Type.Kind.WChar).translate.shouldEqual("wchar");
}

@("short")
@safe pure unittest {
    Type(Type.Kind.Short).translate.shouldEqual("short");
}

@("int")
@safe pure unittest {
    Type(Type.Kind.Int).translate.shouldEqual("int");
}

@("long")
@safe pure unittest {
    version(Windows)
        Type(Type.Kind.Long).translate.shouldEqual("int");
    else
        Type(Type.Kind.Long).translate.shouldEqual("long");
}

@("long long")
@safe pure unittest {
    Type(Type.Kind.LongLong).translate.shouldEqual("long");
}

@("int128")
@safe pure unittest {
    Type(Type.Kind.Int128).translate.shouldEqual("cent");
}

@("float")
@safe pure unittest {
    Type(Type.Kind.Float).translate.shouldEqual("float");
}

@("double")
@safe pure unittest {
    Type(Type.Kind.Double).translate.shouldEqual("double");
}

@("long double")
@safe pure unittest {
    Type(Type.Kind.LongDouble).translate.shouldEqual("real");
}

@("nullptr")
@safe pure unittest {
    Type(Type.Kind.NullPtr).translate.shouldEqual("void*");
}

@("float128")
@safe pure unittest {
    Type(Type.Kind.Float128).translate.shouldEqual("real");
}

@("half")
@safe pure unittest {
    Type(Type.Kind.Half).translate.shouldEqual("float");
}
