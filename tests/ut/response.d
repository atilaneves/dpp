module ut.reponse;

import dpp.test;
import dpp.runtime.response;

@("toConstStringz")
@safe unittest
{
    import core.stdc.string : strlen;
    import std.algorithm : until;
    import std.conv : text;
    foreach (s; [null, "", "a", "áåâà", "fd\0fds"])
    {
        // make sure we're not being saved by string
        // literals being null-terminated
        auto cstr = (() => (s ~ 'a')[0 .. $ - 1])()
            .toConstStringz;
        static assert(is(typeof(cstr) == const(char)*));
        (() @trusted => cstr[0 .. strlen(cstr)])()
            .shouldEqual(s.until('\0').text);
    }
}
