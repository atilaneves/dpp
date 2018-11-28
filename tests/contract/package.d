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

/**
   Create a variable called `tu` that is either a MockCursor or a real
   clang one depending on the type T
 */
mixin template createTU(T, string moduleName, string testName) {
    mixin(mockTuMixin);
    static if(is(T == Cursor))
        const tu = parse!(moduleName, testName);
    else
        auto tu = mockTU.create();
}


/**
   To be used as a UDA on contract tests establishing how to create a mock
   translation unit cursor that behaves _exactly_ the same as the one
   obtained by libclang. This is enforced at contract test time.
*/
struct MockTU(alias F) {
    alias create = F;
}

string mockTuMixin(in string file = __FILE__, in size_t line = __LINE__) @safe pure {
    import std.format: format;
    return q{
        import std.traits: getUDAs;
        alias mockTuUdas = getUDAs!(__traits(parent, {}), MockTU);
        static assert(mockTuUdas.length == 1, "%s:%s Only one @MockTU allowed");
        alias mockTU = mockTuUdas[0];
    }.format(file, line);
}

/// Walks like a clang.Cursor, quacks like a clang.Cursor
struct MockCursor {
    import clang: Cursor;

    Cursor.Kind kind;
    string spelling;
    MockType type;
    MockCursor[] children;

    // Returns a pointer so that the child can be modified
    MockCursor* child(this This)(int index) {
        return &children[index];
    }
}

const(Cursor) child(in Cursor cursor, int index) {
    return cursor.children[index];
}

/// Walks like a clang.Type, quacks like a clang.Type
struct MockType {
    import clang: Type;

    Type.Kind kind;
    string spelling;
}


struct TestName { string value; }
// The name of the module that contains the C/C++ code
struct CodeModule { string value; }
// The name of the test that has the C/C++ code UDA
struct CodeTest { string value; }

/**
   Defines a contract test by mixing in a new function.

   This actually does two things:
   1) Verify the contract that libclang returns what we expect it to.
   2) Use the *same* code to construct a mock translation unit cursor
      that also satisfies the contract.

   Parameters:
        testName = The name of the new test.
        codeModuleName = The name of the IT module with the C code to parse
        codeTestName = The name of the integration test with the C code to parse
        contractFunction = The function that both checks the contract and constructs the mock
 */
mixin template Contract(TestName testName,  // the name for the new test
                        CodeModule codeModuleName, // the name of the module with the C code
                        CodeTest codeTestName,  // the name of the test with the C code
                        alias contractFunction,  // the function to check contract / build mock
                        size_t line = __LINE__)
{
    import unit_threaded: unittestFunctionName;
    import std.format: format;

    enum functionName = unittestFunctionName(line);

    enum code = q{

        @Name("%s")
        @UnitTest
        @Types!(Cursor, MockCursor)
        void %s(T)()
        {
            static if(is(T == Cursor))
                const tu = parse!("%s", "%s");
            else {
                MockCursor tu;
                contractFunction!(TestMode.mock)(tu);
            }

            contractFunction!(TestMode.verify)(tu);
        }
    }.format(testName.value, functionName, codeModuleName.value, codeTestName.value);

    pragma(msg, code);

    mixin(code);
}



enum TestMode {
    verify,  // check that the value is as expected (contract test)
    mock,    // create a mock object that behaves like the real thing
}


/**
   Depending the mode, either assign the given value to lhs
   or assert that lhs == rhs.
   Used in contract functions.
 */
void expectEqual(TestMode mode, L, R)
                (ref L lhs, auto ref R rhs, in string file = __FILE__, in size_t line = __LINE__)
{
    static if(mode == TestMode.verify)
        lhs.shouldEqual(rhs, file, line);
    else static if(mode == TestMode.mock)
        lhs = rhs;
     else
        static assert(false, "Unknown mode " ~ mode.stringof);
}


void expectLengthEqual(TestMode mode, R)
                      (auto ref R range, in size_t length, in string file = __FILE__, in size_t line = __LINE__)
{
    static if(mode == TestMode.verify)
        range.length.shouldEqual(length, file, line);
    else static if(mode == TestMode.mock)
        range.length = length;
     else
        static assert(false, "Unknown mode " ~ mode.stringof);
}


auto expect(TestMode mode, L)
           (ref L lhs, in string file = __FILE__, in size_t line = __LINE__)
{
    struct Expect {

        bool opEquals(R)(auto ref R rhs) {
            expectEqual!mode(lhs, rhs, file, line);
            return true;
        }
    }

    return Expect();
}
