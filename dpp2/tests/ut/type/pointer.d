module ut.type.pointer;


import ut.type;


@("int*")
@safe pure unittest {
    enum translation = translate(Type(Pointer(new Type(Int()))));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == int*), typeof(x).stringof);
}

@("int**")
@safe pure unittest {
    enum translation = translate(Type(Pointer(new Type(Pointer(new Type(Int()))))));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == int**), typeof(x).stringof);
}

@("double*")
@safe pure unittest {
    enum translation = translate(Type(Pointer(new Type(Double()))));
    mixin(translation ~ " x;");
    static assert(is(typeof(x) == double*), typeof(x).stringof);
}
