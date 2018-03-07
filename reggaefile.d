import reggae;

enum debugFlags = "-w -g -debug";

mixin build!(
    dubDefaultTarget!(),
    dubTestTarget!(CompilerFlags(debugFlags)),
    dubConfigurationTarget!(Configuration("unittest-light"),
                            CompilerFlags(debugFlags ~ " -version=unitThreadedLight")),
);
