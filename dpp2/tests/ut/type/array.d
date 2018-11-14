module ut.type.array;


import ut.type;


@("constant int array 4")
@safe pure unittest {
    enum translation = translate(Type(ConstantArray(new Type(Int()), 4)));
    mixin(translation ~ " arr;");
    static assert(is(typeof(arr) == int[4]), typeof(arr).stringof);
}

@("constant int array 5")
@safe pure unittest {
    enum translation = translate(Type(ConstantArray(new Type(Int()), 5)));
    mixin(translation ~ " arr;");
    static assert(is(typeof(arr) == int[5]), typeof(arr).stringof);
}

@("constant long array 6")
@safe pure unittest {
    enum translation = translate(Type(ConstantArray(new Type(Long()), 6)));
    mixin(translation ~ " arr;");
    static assert(is(typeof(arr) == long[6]), typeof(arr).stringof);
}
