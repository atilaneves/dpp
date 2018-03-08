import reggae;

enum debugFlags = "-w -g -debug";

mixin build!(
    dubDefaultTarget!(CompilerFlags(debugFlags)),
    dubTestTarget!(CompilerFlags(debugFlags)),
);
