module dpp2.type;

import dpp.from;

//alias Type = from!"dpp2.sum".Sum!(ConstantArray, int);
alias Type = from!"sumtype".SumType!(Void, Int, Long, ConstantArray);

struct Void {}
struct Int {}
struct Long {}

struct ConstantArray {
    Type* elementType;
    int length;
}
