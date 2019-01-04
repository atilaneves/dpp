module dpp.config;
import std.experimental.all;
import dpp.util:safeArray;

private string readAsString(string filename) @trusted
{
    static import std.file;
    return cast(string)(std.file.read(filename));
}

string[] readBlacklistFile(string filename) @safe
{
    static import std.file;
    import std.string:splitLines,strip;
    import std.array:array;
    import std.algorithm:map,filter,startsWith;

    auto lines = readAsString(filename)
            .splitLines
            .map!(line=>line.strip)
            .array
            .filter!(l=>l.length>0 && !l.startsWith("//"))
            .array;
    return lines;
}

struct TypeRemapping
{
    string originalType;
    string replacementType;
    bool addFirstSizeOfArgument;
    bool isRegex;
}

private enum BackQuote='`';

private bool originalTypeIsRegex(string typeName) pure @trusted
{
    return (typeName.length>2 && typeName[0]==BackQuote  && typeName[$-1] ==BackQuote);
}

private string stripBackQuotes(string typeName) pure @safe
{
    import std.string:replace;
    return typeName.replace([BackQuote],"");
}

private TypeRemapping readTypeRemappingLine(string line) @safe
{
    import std.exception:enforce;
    import std.string:strip,toUpper,split;
    import std.array:array;
    import std.algorithm:map;

    TypeRemapping ret;
    auto cols = line.split(',')
            .map!(col=>col.strip)
            .array;
    enforce(cols.length>=2);
    auto originalType = cols[0];
    ret.isRegex = originalTypeIsRegex(originalType);
    ret.originalType = originalType.stripBackQuotes;
    ret.replacementType = cols[1];
    ret.addFirstSizeOfArgument = (cols.length>2 && (cols[2].toUpper =="Y" || cols[2].toUpper=="TRUE"));
    return ret;
}

TypeRemapping[] readTypeRemappingsFile(string filename) @safe
{
    static import std.file;
    import std.string:splitLines,strip,split,toUpper;
    import std.array:array;
    import std.algorithm:map,filter,startsWith;

    auto lines = readAsString(filename)
            .splitLines
            .map!(line=>line.strip)
            .array
            .filter!(l=>l.length>0 && !l.startsWith("//"))
            .array
            .map!(line => readTypeRemappingLine(line))
            .array;
    return lines;
}

private bool isOpaqueType(string typeName) pure @safe
{
    import std.string:toLower;
    return (typeName.toLower =="opaque");
}


string[] opaqueTypes(TypeRemapping[] remappings) @safe
{
    import std.algorithm:filter,map;
    import std.array:array;
    return remappings.filter!(remappings => remappings.replacementType.isOpaqueType)
            .map!(remapping => remapping.originalType)
            .safeArray;
}

const(TypeRemapping)[] nonOpaqueTypeRemappings(const scope TypeRemapping[] typeRemappings) @safe
{
    import std.algorithm:filter,map;
    import std.array:array;
    return typeRemappings
        .filter!(type => !type.replacementType.isOpaqueType)
        .safeArray;
}


 // FIXME - maybe should be std.algorithm.any with lambda
bool canFindAny(string[] haystack,string needle) @safe pure
{
    import std.algorithm:canFind;

     foreach(e;haystack)
    {
        // deliberate - if needle contains in part the blacklist then blacklist
        if (needle.canFind(e))
            return true;
    }
    return false;
}

