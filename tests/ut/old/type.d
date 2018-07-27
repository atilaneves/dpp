module ut.old.type;

import dpp.test;
import dpp.translation.type;
import clang: Type;


string translate(in from!"clang".Type type) @safe pure {
    import dpp.translation.type: translate_ = translate;
    import dpp.runtime.context: Context;
    Context context;
    return translate_(type, context);
}

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
    Type(Type.Kind.ULong).translate.shouldEqual("c_ulong");
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
    Type(Type.Kind.Char_S).translate.shouldEqual("char");
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
    Type(Type.Kind.Long).translate.shouldEqual("c_long");
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
