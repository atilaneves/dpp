/**
   Pertaining to nodes in the C/C++ AST.
 */
module dpp2.sea.node;


import dpp.from;


alias Node = from!"sumtype".SumType!(
    Struct,
    Field,
    Typedef,
);


struct Struct {
    string spelling;
    Node[] nodes;
    // Anonymous structs still have a type, and that type has a name
    string typeSpelling;
}


struct Field {
    import dpp2.sea.type: Type;
    Type type;
    string spelling;
}


struct Typedef {
    import dpp2.sea.type: Type;
    string spelling;
    Type underlying;
}
