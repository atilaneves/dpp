import reggae;
import std.typecons;

enum debugFlags = "-w -g -debug";

mixin build!(
    dubDefaultTarget!(CompilerFlags(debugFlags)),
    dubTestTarget!(CompilerFlags(debugFlags), LinkerFlags(), CompilationMode.package_),
    dubTarget!({Target[] t; return t;})
    (TargetName("utl"),
     configToDubInfo["unittest"],
     debugFlags ~ " -version=unitThreadedLight",
     [],
     Yes.main,
     CompilationMode.module_)
);
