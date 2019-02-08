/**
   C/C++ AST nodes, equivalent to libclang's cursors
 */
module dpp.ast.node;


/**
   A node in the C/C++ AST
 */
struct Node {
    import clang: Cursor;
    alias cursor this;
    Cursor cursor;
}
