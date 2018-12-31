module dpp.util;
import dpp.from;

auto assumePure(T)(T t)
if (from!"std.traits".isFunctionPointer!T || from!"std.traits".isDelegate!T)
{
	import std.traits:functionAttributes, FunctionAttribute,functionLinkage,SetFunctionAttributes;
	enum attrs = functionAttributes!T | FunctionAttribute.pure_;
	return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

