import reggae;
import std.array: join;
import std.typecons: Yes, No;

enum debugFlags = ["-w", "-g", "-debug"];

alias exe = dubDefaultTarget!(CompilerFlags(debugFlags));
alias ut = dubTestTarget!(
    CompilerFlags(debugFlags),
    LinkerFlags(),
);

alias dpp2 = dubTarget!(
    TargetName("dpp2"),
    Configuration("dpp2"),
    CompilerFlags(debugFlags ~ "-unittest"),
    LinkerFlags(),
    Yes.main,
    CompilationMode.all,
);

// unitThreadedLight, compiles the whole project per D package
alias utlPerPackage = dubTarget!(TargetName("utl_per_package"),
                                 Configuration("unittest"),
                                 CompilerFlags(debugFlags ~ "-version=unitThreadedLight"),
);


// The rest of this file is just to set up a custom unit test build
// that compiles the production code per package and the test code
// per module.

// The production code object files
alias prodObjs = dubObjects!(Configuration("default"),
                             CompilerFlags(debugFlags),
                             No.main,
                             CompilationMode.package_);

// The test code object files
// We build the default configuration to avoid depencencies
// or -unittest.
alias testObjsPerPackage = dlangObjectsPerModule!(
    Sources!"tests",
    CompilerFlags(debugFlags ~ ["-unittest", "-version=unitThreadedLight"]),
    dubImportPaths!(Configuration("unittest"))
);


// The object file(s) for unit-threaded.
// `dubDependencies` could give us this, but it'd include libclang and any other
// dependencies compiled with `-unittest`, which we'd rather avoid.
alias unitThreaded = dubPackageObjects!(
    DubPackageName("unit-threaded"),
    Configuration("unittest"),  // or else the dependency doesn't even exist
    CompilerFlags(["-unittest", "-version=unitThreadedLight"]),
);


alias utl = dubLink!(
    TargetName("utl"),
    Configuration("unittest"),
    targetConcat!(prodObjs, testObjsPerPackage, unitThreaded),
    LinkerFlags("-main"),
);



mixin build!(
    exe,
    optional!ut,  // investigate UT failures
    optional!utl,  // fast development
    optional!utlPerPackage,  // for benchmarking
    optional!dpp2,
);
