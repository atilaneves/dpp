module dpp2.type;

import dpp.from;

alias Type = from!"dpp2.sum".Sum!(Void, Int, Long, ConstantArray);

struct Void {}
struct Int {}
struct Long {}

struct ConstantArray {
    Type* elementType;
    int length;
}
