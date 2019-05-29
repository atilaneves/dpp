/**
   Contract tests for libclang.
   https://martinfowler.com/bliki/ContractTest.html
 */
module contract;

import dpp.from;

public import unit_threaded;
public import clang: Cursor, Type;
public import common: printChildren, shouldMatch;

struct C {
    string value;
}


struct Cpp {
    string value;
}

/**
   A way to identify a snippet of C/C++ code for testing.

   A test exists somewhere in the code base named `test` in a D module `module_`.
   This test has an attached UDA with a code snippet.
*/
struct CodeURL {
    string module_;
    string test;
}


/// Parses C/C++ code located in a UDA on `codeURL`
auto parse(CodeURL codeURL)() {
    return parse!(codeURL.module_, codeURL.test);
}


/**
   Parses C/C++ code located in a UDA on `testName`
   which is in module `moduleName`
 */
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
    static assert(getUDAs!(test, it.C).length == 1,
                  "No `C` UDA on " ~ __traits(identifier, test));
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

    alias Kind = Cursor.Kind;

    Kind kind;
    string spelling;
    MockType type;
    MockCursor[] children;
    private MockType _underlyingType;
    bool isDefinition;
    bool isCanonical;

    // Returns a pointer so that the child can be modified
    auto child(this This)(int index) {

        return index >= 0 && index < children.length
            ? &children[index]
            : null;
    }

    auto underlyingType(this This)() return scope {
        return &_underlyingType;
    }

    string toString() @safe pure const {
        import std.conv: text;
        const children = children.length
            ? text(", ", children)
            : "";
        return text("MockCursor(", kind, `, "`, spelling, `"`, children, `)`);
    }
}

const(Cursor) child(in Cursor cursor, int index) @safe {
    return cursor.children[index];
}

/// Walks like a clang.Type, quacks like a clang.Type
struct MockType {
    import clang: Type;

    alias Kind = Type.Kind;

    Kind kind;
    string spelling;
    private MockType* _canonical;

    auto canonical(this This)() return scope {
        static if(!is(This == const))
            if(_canonical is null) _canonical = new MockType;
        return _canonical;
    }
}


struct TestName { string value; }



/**
   Defines a contract test by mixing in a new test function.

   The test function actually does a few things:
   * Verify the contract that libclang returns what we expect it to.
   * Use the *same* code to construct a mock translation unit cursor
     that also satisfies the contract.
   * Verifies the mock also passes the test.

   Two functions are generated: the contract test, and a helper function
   that does the heavy lifting. The separation is so the 2nd function can
   be called from unit tests to generate the mock.

   This 2nd function isn't supposed to be called directly, but is found
   via compile-time reflection in mockTU.

   Parameters:
        testName = The name of the new test.
        contractFunction = The function that verifies the contract or creates the mock.
 */
mixin template Contract(TestName testName, alias contractFunction, size_t line = __LINE__) {
    import unit_threaded: unittestFunctionName;
    import std.format: format;
    import std.traits: getUDAs;

    alias udas = getUDAs!(contractFunction, ContractFunction);
    static assert(udas.length == 1,
        "`" ~ __traits(identifier, contractFunction) ~
                  "` is not a contract function without exactly one @ContractFunction`");
    enum codeURL = udas[0].codeURL;

    enum testFunctionName = unittestFunctionName(line);
    enum code = q{

        // This is the test function that will be run by unit-threaded
        @Name("%s")
        @UnitTest
        @Types!(Cursor, MockCursor)
        void %s(CursorType)()
        {
            auto tu = createTranslationUnit!(CursorType, codeURL, contractFunction);
            contractFunction!(TestMode.verify)(cast(const) tu);
        }
    }.format(testName.value, testFunctionName);

    //pragma(msg, code);

    mixin(code);

}

/**
   Creates a real or mock translation unit depending on the type
 */
auto createTranslationUnit(CursorType, CodeURL codeURL, alias contractFunction)() {
    import std.traits: Unqual;
    static if(is(Unqual!CursorType == Cursor))
        return cast(const) createRealTranslationUnit!codeURL;
    else
        return createMockTranslationUnit!contractFunction;

}

auto createRealTranslationUnit(CodeURL codeURL)() {
    return parse!(codeURL.module_, codeURL.test);
}


auto createMockTranslationUnit(alias contractFunction)() {
    MockCursor tu;
    contractFunction!(TestMode.mock)(tu);
    return tu;
}

enum TestMode {
    verify,  // check that the value is as expected (contract test)
    mock,    // create a mock object that behaves like the real thing
}


/**
   To be used as a UDA indicating a function that does double duty as:
   * a contract test
   * builds a mock to satisfy the same contract
 */
struct ContractFunction {
    CodeURL codeURL;
}

struct Module {
    string name;
}

/**
   Searches `moduleName` for a contract function that creates a mock
   translation unit cursor, calls it, and returns the value
 */
auto mockTU(Module moduleName, CodeURL codeURL)() {

    mixin(`import `, moduleName.name, `;`);
    import std.meta: Alias, AliasSeq, Filter, staticMap;
    import std.traits: hasUDA, getUDAs;
    import std.algorithm: startsWith;
    import std.conv: text;

    alias module_ = Alias!(mixin(moduleName.name));
    alias memberNames = AliasSeq!(__traits(allMembers, module_));
    enum hasContractName(string name) = name.startsWith("contract_");
    alias contractNames = Filter!(hasContractName, memberNames);

    alias Member(string name) = Alias!(mixin(name));
    alias contractFunctions = staticMap!(Member, contractNames);
    enum hasURL(alias F) =
        hasUDA!(F, ContractFunction)
        && getUDAs!(F, ContractFunction).length == 1
        && getUDAs!(F, ContractFunction)[0].codeURL == codeURL;
    alias contractFunctionsWithURL = Filter!(hasURL, contractFunctions);

    static assert(contractFunctionsWithURL.length > 0,
                  text("Cannot find ", codeURL, " anywhere in module ", moduleName.name));

    enum identifier(alias F) = __traits(identifier, F);
    static assert(contractFunctionsWithURL.length == 1,
                  text("Too many (", contractFunctionsWithURL.length,
                       ") contract functions for ", codeURL, " in ", moduleName.name, ": ",
                       staticMap!(identifier, contractFunctionsWithURL)));

    alias contractFunction = contractFunctionsWithURL[0];

    MockCursor cursor;
    contractFunction!(TestMode.mock)(cursor);
    return cursor;
}


auto expect(L)
           (auto ref L lhs, in string file = __FILE__, in size_t line = __LINE__)
{
    struct Expect {

        bool opEquals(R)(auto ref R rhs) {
            import std.functional: forward;
            enum mode = InferTestMode!lhs;
            expectEqualImpl!mode(forward!lhs, forward!rhs, file, line);
            return true;
        }
    }

    return Expect();
}

// Used with Cursor and Type objects, simultaneously assert the kind and spelling
// of the passed in object, or actually set those values when mocking
auto expectEqual(L, K)
                (auto ref L lhs, in K kind, in string spelling, in string file = __FILE__, in size_t line = __LINE__)
{
    enum mode = InferTestMode!lhs;
    expectEqualImpl!mode(lhs.kind, kind, file, line);
    expectEqualImpl!mode(lhs.spelling, spelling, file, line);
}


/**
   Calculate if we're in mocking or verifying mode using reflection
 */
template InferTestMode(alias lhs) {
    import std.traits: isPointer;

    alias L = typeof(lhs);

    template isConst(T) {
        import std.traits: isPointer, PointerTarget;
        static if(isPointer!T)
            enum isConst = isConst!(PointerTarget!T);
        else
            enum isConst = is(T == const);
    }

    static if(!__traits(isRef, lhs) && !isPointer!L)
        enum InferTestMode = TestMode.verify;  // can't modify non-ref
    else static if(isConst!L)
        enum InferTestMode = TestMode.verify;  // can't modify const
    else
        enum InferTestMode = TestMode.mock;
}

/**
   Depending the mode, either assign the given value to lhs
   or assert that lhs == rhs.
   Used in contract functions.
 */
private void expectEqualImpl(TestMode mode, L, R)
                            (auto ref L lhs, auto ref R rhs, in string file = __FILE__, in size_t line = __LINE__)
    if(is(typeof(lhs == rhs) == bool) || is(R == L*))
{
    import std.traits: isPointer, PointerTarget;

    static if(mode == TestMode.verify) {
        static if(isPointer!L && isPointer!R)
            (*lhs).shouldEqual(*rhs, file, line);
        else static if(isPointer!L)
            (*lhs).shouldEqual(rhs, file, line);
        else static if(isPointer!R)
            lhs.shouldEqual(*rhs, file, line);
        else
            lhs.shouldEqual(rhs, file, line);
    } else static if(mode == TestMode.mock) {

        static if(isPointer!L && isPointer!R)
            *lhs = *rhs;
        else static if(isPointer!L)
            *lhs = rhs;
        else static if(isPointer!R)
            lhs = *rhs;
        else {
            lhs = rhs;
        }
    } else
        static assert(false, "Unknown mode " ~ mode.stringof);
}


auto expectLength(L)
                 (auto ref L lhs, in string file = __FILE__, in size_t line = __LINE__)
{
    struct Expect {

        bool opEquals(in size_t length) {
            import std.functional: forward;
            enum mode = InferTestMode!lhs;
            expectLengthEqualImpl!mode(forward!lhs, length, file, line);
            return true;
        }
    }

    return Expect();
}


private void expectLengthEqualImpl(TestMode mode, R)
                                  (auto ref R range, in size_t length, in string file = __FILE__, in size_t line = __LINE__)
{
    enum mode = InferTestMode!range;

    static if(mode == TestMode.verify)
        range.length.shouldEqual(length, file, line);
    else static if(mode == TestMode.mock)
        range.length = length;
     else
        static assert(false, "Unknown mode " ~ mode.stringof);
}
