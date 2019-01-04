module dpp.util;
import dpp.from;
import std.traits:ReturnType;

///
auto assumePure(T)(T t) @trusted
if (from!"std.traits".isFunctionPointer!T || from!"std.traits".isDelegate!T)
{
	import std.traits:  functionAttributes,FunctionAttribute,functionLinkage,
                        SetFunctionAttributes;
	enum attrs = functionAttributes!T | FunctionAttribute.pure_;
	return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

///
auto callAssumePure(F,Args...)(F f,Args args) @trusted
if (from!"std.traits".isFunctionPointer!F || from!"std.traits".isDelegate!F)
{
	auto dg = assumePure(f);
	return dg(args);
}


// ???  Map and Filter don't return InputRanges?
///
auto safeArray(Range)(Range range) @trusted // because filter is system
if (from!"std.range".isInputRange!Range || 
    is(Range==from!"std.algorithm".FilterResult) || 
    is(Range==from!"std.algorithm".MapResult))
{
    import std.array:Appender;
    alias T = from!"std.range".ElementType!(Range);
    Appender!(T[]) ret;
    foreach(ref e;range)
        ret.put(e);
    return ret.data;
}

auto mutableT(T)(T t) @trusted pure
{
    import std.traits:Unqual;
    return cast(Unqual!T) t;
}
