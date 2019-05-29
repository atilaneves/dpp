module ut.old.type;


import dpp.from;
import dpp.translation.type;
import clang: Type;
import unit_threaded;


string translate(in from!"clang".Type type) @safe {
    import dpp.translation.type: translate_ = translate;
    import dpp.runtime.context: Context;
    Context context;
    return translate_(type, context);
}

@("void")
@safe unittest {
    Type(Type.Kind.Void).translate.shouldEqual("void");
}

@("bool")
@safe unittest {
    Type(Type.Kind.Bool).translate.shouldEqual("bool");
}

@("char_u")
@safe unittest {
    Type(Type.Kind.Char_U).translate.shouldEqual("ubyte");
}

@("UChar")
@safe unittest {
    Type(Type.Kind.UChar).translate.shouldEqual("ubyte");
}

@("Char16")
@safe unittest {
    Type(Type.Kind.Char16).translate.shouldEqual("wchar");
}

@("Char32")
@safe unittest {
    Type(Type.Kind.Char32).translate.shouldEqual("dchar");
}

@("unsigned short")
@safe unittest {
    Type(Type.Kind.UShort).translate.shouldEqual("ushort");
}

@("unsigned int")
@safe unittest {
    Type(Type.Kind.UInt).translate.shouldEqual("uint");
}

@("unsigned long")
@safe unittest {
    Type(Type.Kind.ULong).translate.shouldEqual("c_ulong");
}

@("unsigned long long")
@safe unittest {
    Type(Type.Kind.ULongLong).translate.shouldEqual("ulong");
}

@("uint128")
@safe unittest {
    Type(Type.Kind.UInt128).translate.shouldEqual("UInt128");
}

@("char_s")
@safe unittest {
    Type(Type.Kind.Char_S).translate.shouldEqual("char");
}

@("SChar")
@safe unittest {
    Type(Type.Kind.SChar).translate.shouldEqual("byte");
}

@("WChar")
@safe unittest {
    Type(Type.Kind.WChar).translate.shouldEqual("wchar");
}

@("short")
@safe unittest {
    Type(Type.Kind.Short).translate.shouldEqual("short");
}

@("int")
@safe unittest {
    Type(Type.Kind.Int).translate.shouldEqual("int");
}

@("long")
@safe unittest {
    Type(Type.Kind.Long).translate.shouldEqual("c_long");
}

@("long long")
@safe unittest {
    Type(Type.Kind.LongLong).translate.shouldEqual("long");
}

@("int128")
@safe unittest {
    Type(Type.Kind.Int128).translate.shouldEqual("Int128");
}

@("float")
@safe unittest {
    Type(Type.Kind.Float).translate.shouldEqual("float");
}

@("double")
@safe unittest {
    Type(Type.Kind.Double).translate.shouldEqual("double");
}

@("long double")
@safe unittest {
    Type(Type.Kind.LongDouble).translate.shouldEqual("real");
}

@("nullptr")
@safe unittest {
    Type(Type.Kind.NullPtr).translate.shouldEqual("void*");
}

@("float128")
@safe unittest {
    Type(Type.Kind.Float128).translate.shouldEqual("real");
}

@("half")
@safe unittest {
    Type(Type.Kind.Half).translate.shouldEqual("float");
}
