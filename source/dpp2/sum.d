module dpp2.sum;

import dpp.from;

alias Sum = from!"sumtype".SumType;

// struct Sum(T...) {
//     import sumtype: SumType;

//     private SumType!T sumType;

//     @disable this();

//     this(U)(auto ref U u) {
//         import std.functional: forward;
//         this.sumType = SumType!T(forward!u);
//     }

//     auto match(A...)() {
//         return sumType.match!A;
//     }
// }
