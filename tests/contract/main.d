import unit_threaded.runner;

mixin runTestsMain!(
    "contract.array",
    "contract.templates",
    "contract.namespace",
    "contract.macro_",
    "contract.constexpr",
    "contract.typedef_",
    "contract.operators",
    "contract.member",
    "contract.aggregates",
    "contract.inheritance",
    "contract.issues",
    "contract.methods",
    "contract.functions",
);
