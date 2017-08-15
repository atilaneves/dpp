import reggae;
mixin build!(dubDefaultTarget!(),
             dubTestTarget!(CompilerFlags("-g -debug")),
             dubConfigurationTarget!(Configuration("integration"),
                                     CompilerFlags("-unittest -g -debug"),
                                     LinkerFlags(),
                                     Yes.main,
                                     Yes.allTogether,
                 ));
