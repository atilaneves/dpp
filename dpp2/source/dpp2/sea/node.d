/**
   Pertaining to nodes in the C/C++ AST.
 */
module dpp2.sea.node;


import dpp.from;


alias Node = from!"sumtype".SumType!(
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
