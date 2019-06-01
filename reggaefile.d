import reggae;
import std.array: join;
import std.typecons: Yes, No;

enum debugFlags = ["-w", "-g", "-debug"];
enum releaseFlags = ["-O", "-inline", "-release"];

alias exe = dubDefaultTarget!(CompilerFlags(releaseFlags));

alias lib = dubConfigurationTarget!(
    Configuration("library"),
    CompilerFlags(debugFlags),
    LinkerFlags(),
    No.main,
    CompilationMode.package_,
);

enum mainObj = objectFile(
    SourceFile("source/main.d"),
    Flags(debugFlags),
    ImportPaths("source")
);

alias utOld = dubTestTarget!(
    CompilerFlags(debugFlags),
    LinkerFlags(),
);

// alias ut = dubLink!(
//     TargetName("ut"),
//     Configuration("unittest"),
//     targetConcat!(lib, testObjs, dubDependencies!(Configuration("unittest"))),
// );
alias all_tests = dubTestTarget!(
    CompilerFlags(debugFlags),
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

// The test code object files
// We build the default configuration to avoid depencencies
// or -unittest.
alias testObjsLight = dlangObjectsPerModule!(
    Sources!"tests",
    CompilerFlags(debugFlags ~ ["-unittest", "-version=unitThreadedLight"]),
    dubImportPaths!(Configuration("unittest"))
);


alias testObjs = dlangObjectsPerModule!(
    Sources!"tests",
    CompilerFlags(debugFlags ~ ["-unittest"]),
    dubImportPaths!(Configuration("unittest"))
);



// The object file(s) for unit-threaded.
// `dubDependencies` could give us this, but it'd include libclang and any other
// dependencies compiled with `-unittest`, which we'd rather avoid.
alias unitThreadedLight = dubPackageObjects!(
    DubPackageName("unit-threaded"),
    Configuration("unittest"),  // or else the dependency doesn't even exist
    CompilerFlags(["-unittest", "-version=unitThreadedLight"]),
);


alias utl = dubLink!(
    TargetName("utl"),
    Configuration("unittest"),
    targetConcat!(lib, testObjsLight, unitThreadedLight),
    LinkerFlags("-main"),
);


alias it = dubConfigurationTarget!(
    Configuration("integration"),
    CompilerFlags(debugFlags ~ "-unittest"),
);


alias ct = dubConfigurationTarget!(
    Configuration("contract"),
    CompilerFlags(debugFlags ~ "-unittest"),
);


mixin build!(
    exe,
    optional!all_tests,
    optional!it,
    optional!ct,
    optional!utl,  // fast development
    optional!utlPerPackage,  // for benchmarking
    optional!dpp2,
);
