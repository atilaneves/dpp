module ut.translation.type.primitives;


import ut.translation.type;


@("void")
@safe pure unittest {
    enum translation = translate(Type(Void()));
    mixin(translation ~ "[] x;");
    static assert(is(typeof(x) == void[]), typeof(x).stringof);
}

@("nullptr_t")
@safe pure unittest {
    enum translation = translate(Type(NullPointerT()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == void*), typeof(x).stringof);
}

@("bool")
@safe pure unittest {
    enum translation = translate(Type(Bool()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == bool), typeof(x).stringof);
}

@("unsigned char")
@safe pure unittest {
    enum translation = translate(Type(UnsignedChar()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == ubyte), typeof(x).stringof);
}

@("signed char")
@safe pure unittest {
    enum translation = translate(Type(SignedChar()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == byte), typeof(x).stringof);
}

@("char")
@safe pure unittest {
    enum translation = translate(Type(Char()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == char), typeof(x).stringof);
}

@("char16_t")
@safe pure unittest {
    enum translation = translate(Type(Char16()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == wchar), typeof(x).stringof);
}

@("char32_t")
@safe pure unittest {
    enum translation = translate(Type(Char32()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == dchar), typeof(x).stringof);
}

@("wchar_t")
@safe pure unittest {
    enum translation = translate(Type(Wchar()));
    mixin(translation ~ " x;");
    version(Windows)
        static assert(is(typeof(x) == wchar), typeof(x).stringof);
    else
        static assert(is(typeof(x) == dchar), typeof(x).stringof);
}

@("short")
@safe pure unittest {
    enum translation = translate(Type(Short()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == short), typeof(x).stringof);
}

@("ushort")
@safe pure unittest {
    enum translation = translate(Type(UnsignedShort()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == ushort), typeof(x).stringof);
}

@("int")
@safe pure unittest {
    enum translation = translate(Type(Int()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == int), typeof(x).stringof);
}

@("uint")
@safe pure unittest {
    enum translation = translate(Type(UnsignedInt()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == uint), typeof(x).stringof);
}

@("long")
@safe pure unittest {
    enum translation = translate(Type(Long()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == long), typeof(x).stringof);
}

@("ulong")
@safe pure unittest {
    enum translation = translate(Type(UnsignedLong()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == ulong), typeof(x).stringof);
}

@("longlong")
@safe pure unittest {
    enum translation = translate(Type(LongLong()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == long), typeof(x).stringof);
}

@("ulonglong")
@safe pure unittest {
    enum translation = translate(Type(UnsignedLongLong()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == ulong), typeof(x).stringof);
}

@("float")
@safe pure unittest {
    enum translation = translate(Type(Float()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == float), typeof(x).stringof);
}

@("double")
@safe pure unittest {
    enum translation = translate(Type(Double()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == double), typeof(x).stringof);
}

@("long double")
@safe pure unittest {
    enum translation = translate(Type(LongDouble()));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == real), typeof(x).stringof);
}
