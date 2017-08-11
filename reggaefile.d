import reggae;
mixin build!(dubDefaultTarget!(),
             dubTestTarget!(),
             dubConfigurationTarget!(Configuration("integration"),
                                     Flags("-unittest -g -debug"),
                                     Yes.main,
                                     Yes.allTogether,
                 ));
