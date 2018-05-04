module ut.response;

import dpp.test;
import dpp.runtime.response;

@("toConstStringz")
@safe unittest
{
    import std.algorithm : until;
    foreach (s; [null, "", "a", "áåâà", "fd\0fds"])
    {
        // make sure we're not being saved by string
        // literals being null-terminated
        auto cstr = (s ~ 'a')[0 .. $ - 1]
            .toConstStringz;
        static assert(is(typeof(cstr) == const(char)*));
        (() @trusted => cstr[0 .. s.length + 1])().until('\0')
            .shouldEqual(s.until('\0'));
    }
}
