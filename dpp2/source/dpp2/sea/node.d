/**
   Pertaining to nodes in the C/C++ AST.
 */
module dpp2.sea.node;


import dpp.from;


alias Node = from!"dpp2.sum".Sum!(
    Struct,
);


struct Struct {
    string spelling;
    Field[] fields;
}


struct Field {
    import dpp2.sea.type: Type;
    Type type;
    string spelling;
}
