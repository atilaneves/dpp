module dpp.util;
import dpp.from;
import std.traits:ReturnType;

auto assumePure(T)(T t) @trusted
if (from!"std.traits".isFunctionPointer!T || from!"std.traits".isDelegate!T)
{
	import std.traits:functionAttributes, FunctionAttribute,functionLinkage,SetFunctionAttributes;
	enum attrs = functionAttributes!T | FunctionAttribute.pure_;
	return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) t;
}

auto callAssumePure(F,Args...)(F f,Args args) @trusted
if (from!"std.traits".isFunctionPointer!F || from!"std.traits".isDelegate!F)
{
	auto dg = assumePure(f);
	return dg(args);
}
