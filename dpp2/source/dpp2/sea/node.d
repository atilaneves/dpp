/**
   Pertaining to nodes in the C/C++ AST.
 */
module dpp2.sea.node;


import dpp.from;


alias Node = from!"dpp2.sum".Sum!(
    Struct,
    Field,
);


struct Struct {
    string spelling;
    Node[] nodes;
}


struct Field {
    import dpp2.sea.type: Type;
    Type type;
    string spelling;
}
