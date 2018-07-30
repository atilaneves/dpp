module ut.type.primitives;

import ut.type;

@("void")
@safe pure unittest {
    enum translation = translate(Type(Void()));
    mixin(translation ~ " x[];");
    static assert(is(typeof(x) == void[]), typeof(x).stringof);
}
