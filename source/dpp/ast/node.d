/**
   C/C++ AST nodes, equivalent to libclang's cursors
 */
module dpp.ast.node;


/**
   A node in the C/C++ AST
 */
struct Node {
    import sumtype: SumType;
    import clang: Cursor;

    alias Hash = Cursor.Hash;
    alias Declaration = SumType!(
        EnumMember,
        ClangCursor,
    );

    string spelling;
    Declaration declaration;

    // used for anonymous aggregates
    Hash hash() @safe pure const {
        import sumtype: match;

        static Hash otherwise() {
            throw new Exception("Can only hash a libclang Cursor");
        }

        return declaration.match!(
            (in ClangCursor cursor) => cursor.hash,
            _ => otherwise,
        );
    }
}


struct EnumMember {
    long value;
}

/**
   For backwards compatibility, just a clang cursor.
 */
struct ClangCursor {
    import clang: Cursor;
    alias cursor this;
    Cursor cursor;
}
