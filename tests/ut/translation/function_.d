module ut.translation.function_;

import ut.translation;

// @("struct Foo addFoos(struct Foo*, struct Foo*)")
// @safe unittest {

//     const function_ = Cursor(Cursor.Kind.FunctionDecl,
//                              "addFoos",
//                              Type(Type.Kind.FunctionProto, "struct Foo (struct Foo*, struct Foo*)"),
//                              Type(Type.Kind.Elaborated, "struct Foo"));

//     translateFunction(function_).shouldEqual(
//         [
//             q{Foo addFoos(Foo*, Foo*);},
//         ]
//     );
// }

// @("struct Bar addBars(struct Bar*, struct Bar*)")
// @safe unittest {

//     const function_ = Cursor(Cursor.Kind.FunctionDecl,
//                              "addBars",
//                              Type(Type.Kind.FunctionProto, "struct Bar (struct Bar*, struct Bar*)"),
//                              Type(Type.Kind.Elaborated, "struct Bar"));

//     translateFunction(function_).shouldEqual(
//         [
//             q{Bar addBars(Bar*, Bar*);},
//         ]
//     );
// }
