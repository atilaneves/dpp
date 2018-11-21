/**
   Contract tests for libclang.
   https://martinfowler.com/bliki/ContractTest.html
 */
module contract;

import dpp.from;

public import unit_threaded;
public import clang: Cursor, Type;


struct C {
    string value;
}


struct Cpp {
    string value;
}


auto parse(string moduleName, string testName)() {
    mixin(`static import ` ~ moduleName ~ ";");
    static import it;
    import std.meta: AliasSeq, staticMap, Filter;
    import std.traits: getUDAs, isSomeString;

    alias tests = AliasSeq!(__traits(getUnitTests, mixin(moduleName)));

    template TestName(alias T) {
        alias attrs = AliasSeq!(__traits(getAttributes, T));

        template isSomeString_(alias S) {
            static if(is(typeof(S)))
                enum isSomeString_ = isSomeString!(typeof(S));
            else
                enum isSomeString_ = false;
        }
        alias strAttrs = Filter!(isSomeString_, attrs);
        static assert(strAttrs.length == 1);
        enum TestName = strAttrs[0];
    }

    enum hasRightName(alias T) = TestName!T == testName;
    alias rightNameTests = Filter!(hasRightName, tests);
    static assert(rightNameTests.length == 1);
    alias test = rightNameTests[0];
    enum cCode = getUDAs!(test, it.C)[0];

    return .parse(C(cCode.code));
}


C cCode(string moduleName, int index = 0)() {
    mixin(`static import ` ~ moduleName ~ ";");
    static import it;
    import std.meta: Alias;
    import std.traits: getUDAs;
    alias test = Alias!(__traits(getUnitTests, it.c.compile.struct_)[index]);
    enum cCode = getUDAs!(test, it.C)[0];
    return C(cCode.code);
}

auto parse(T)
          (
              in T code,
              in from!"clang".TranslationUnitFlags tuFlags = from!"clang".TranslationUnitFlags.None,
          )
{
    import unit_threaded.integration: Sandbox;
    import clang: parse_ = parse;

    enum isCpp = is(T == Cpp);

    with(immutable Sandbox()) {
        const extension = isCpp ? "cpp" : "c";
        const fileName = "code." ~ extension;
        writeFile(fileName, code.value);

        auto tu = parse_(inSandboxPath(fileName),
                         isCpp ? ["-std=c++14"] : [],
                         tuFlags)
            .cursor;
        printChildren(tu);
        return tu;
    }
}


void printChildren(T)(auto ref T cursorOrTU) {
    import clang: TranslationUnit, Cursor;

    static if(is(T == TranslationUnit) || is(T == Cursor)) {

        import unit_threaded.io: writelnUt;
        import std.algorithm: map;
        import std.array: join;
        import std.conv: text;

        writelnUt("\n", cursorOrTU, " children:\n[\n", cursorOrTU.children.map!(a => text("    ", a)).join(",\n"));
        writelnUt("]\n");
    }
}


/// Walks like a clang.Cursor, quacks like a clang.Cursor
struct MockCursor {
    import clang: Cursor;

    Cursor.Kind kind;
    string spelling;
    MockCursor[] children;
    MockType type;
}

/// Walks like a clang.Type, quacks like a clang.Type
struct MockType {
    import clang: Type;

    Type.Kind kind;
    string spelling;
}


/**
   To be used as a UDA on contract tests establishing how to create a mock
   translation unit cursor that behaves _exactly_ the same as the one
   obtained by libclang. This is enforced at contract test time.
*/
struct MockTU(alias F) {
    alias create = F;
}
