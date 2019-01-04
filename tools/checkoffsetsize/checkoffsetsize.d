import allbonds;
import std.experimental.all;
import std.experimental.logger;
import std.traits;

struct DppOffsetSize
{
	int offset;
	int size;
}

struct T
{
	@DppOffsetSize(1,2) double a;
	@DppOffsetSize(2,10) string b;
}

template OffsetOf(alias T,string F)
{
	mixin("enum OffsetOf = T." ~ F ~ ".offsetof;");
}

template SizeOf(alias T, string F)
{
	mixin("enum SizeOf= T." ~ F ~ ".sizeof;");
}


template GetDppOffsetSize(alias T, string F)
{
	mixin("alias A = __traits(getAttributes,T." ~ F ~ ");");
	static if (A.length == 0)
		enum GetDppOffsetSize =  DppOffsetSize(-2,-2);
	else
		enum GetDppOffsetSize = A[0];
}

void checkType(string moduleName)()
{
	DppOffsetSize[string] dTable;
	DppOffsetSize[string] cppTable;
	string[] fieldOrder;

	mixin("import " ~ moduleName ~ ";");
	mixin("alias Module = " ~ moduleName ~ ";");
	foreach(m; __traits(allMembers,Module))
	{
		pragma(msg,m);
		static if (!__traits(compiles,__traits(getMember,Module,m)))
		{
			pragma(msg, " cannot get "~moduleName~"." ~m);
		}
		else
		{
			alias M =__traits(getMember,Module,m);
			static if (is(typeof(M)))
				pragma(msg, m ~ " : " ~ typeof(M).stringof);
			static if ((is(M == struct) || is(M == class)) && !(is(M==DppOffsetSize)))
			{
				static foreach(i,F;FieldNameTuple!M)
				{
					static if (__traits(getProtection,__traits(getMember,M,F)) == "public")
					{
						dTable[m ~ "." ~F] = DppOffsetSize(OffsetOf!(M,F), SizeOf!(M,F));
						cppTable[m ~ "." ~ F] = GetDppOffsetSize!(M,F);
						fieldOrder ~= m ~ "." ~ F;
					}
					else
					{
						pragma(msg,"cannot access " ~ m ~ "." ~ F);
					}
				}
			}
		}
	}
	writeln(fieldOrder);
	string[] passedItems;
	foreach(entry;fieldOrder)
	{
		auto p = entry in dTable;
		if (p is null)
		{
			infof(entry," is not in D");
			continue;
		}
		auto pCpp = entry in cppTable;
		assert(pCpp !is null);
		bool failed = false;
		if(pCpp.offset != p.offset)
		{
			writeln(text(entry,": cpp.offset = \t",pCpp.offset,"\t/ d.offset = \t",p.offset));
			failed = true;
		}
		if (pCpp.size != p.size)
		{
			writeln(text(entry,": cpp.size = \t", pCpp.size,"\t/ d.size = \t",p.size));
			failed = true;
		}
		if (!failed)
			passedItems ~= entry;
	}
	foreach(e;passedItems)
	{
		writeln("    ",e);
	}
}


