module dpp.runtime.response;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

string[] response_expand(string[] args) @trusted
{
    import std.algorithm : map;
    import std.array : array;
    import std.string : fromStringz;

    auto cargs = args
            .map!toConstStringz
            .array;
    response_expand(cargs);
    return cargs
        .map!(s => s.fromStringz.idup)
        .array;
}

const(char)* toConstStringz(string s) @safe
{
    auto r = new char[](s.length + 1);
    size_t i = 0;
    while (i < s.length)
    {
        r[i] = s[i];
        if (r[i] == '\0')
            break;
        ++i;
    }
    if (i == s.length)
        r[i] = '\0';
    return &r[0];
}

bool response_expand(ref const(char)*[] args)
{
    import std.algorithm : remove;
    import std.file : readText;
    import std.array : insertInPlace;

    const(char)* cp;
    int recurse = 0;
    for (size_t i = 0; i < args.length;)
    {
        cp = args[i];
        if (*cp != '@')
        {
            ++i;
            continue;
        }
        args = args.remove(i);
        char* buffer;
        char* bufend;
        cp++;
        if (auto p = getenv(cp))
        {
            buffer = strdup(p);
            if (!buffer)
                goto noexpand;
            bufend = buffer + strlen(buffer);
        }
        else
        {
            auto s = cp[0 .. strlen(cp)].readText!(char[]);
            buffer = s.ptr;
            bufend = buffer + s.length;
        }
        // The logic of this should match that in setargv()
        int comment = 0;
        for (auto p = buffer; p < bufend; p++)
        {
            char* d;
            char c, lastc;
            ubyte instring;
            int num_slashes, non_slashes;
            switch (*p)
            {
            case 26:
                /* ^Z marks end of file      */
                goto L2;
            case 0xD:
            case '\n':
                if (comment)
                {
                    comment = 0;
                }
                goto case;
            case 0:
            case ' ':
            case '\t':
                continue;
                // scan to start of argument
            case '#':
                comment = 1;
                continue;
            case '@':
                if (comment)
                {
                    continue;
                }
                recurse = 1;
                goto default;
            default:
                /* start of new argument   */
                if (comment)
                {
                    continue;
                }
                args.insertInPlace(i, p);
                ++i;
                instring = 0;
                c = 0;
                num_slashes = 0;
                for (d = p; 1; p++)
                {
                    lastc = c;
                    if (p >= bufend)
                    {
                        *d = 0;
                        goto L2;
                    }
                    c = *p;
                    switch (c)
                    {
                    case '"':
                        /*
                         Yes this looks strange,but this is so that we are
                         MS Compatible, tests have shown that:
                         \\\\"foo bar"  gets passed as \\foo bar
                         \\\\foo  gets passed as \\\\foo
                         \\\"foo gets passed as \"foo
                         and \"foo gets passed as "foo in VC!
                         */
                        non_slashes = num_slashes % 2;
                        num_slashes = num_slashes / 2;
                        for (; num_slashes > 0; num_slashes--)
                        {
                            d--;
                            *d = '\0';
                        }
                        if (non_slashes)
                        {
                            *(d - 1) = c;
                        }
                        else
                        {
                            instring ^= 1;
                        }
                        break;
                    case 26:
                        *d = 0; // terminate argument
                        goto L2;
                    case 0xD:
                        // CR
                        c = lastc;
                        continue;
                        // ignore
                    case '@':
                        recurse = 1;
                        goto Ladd;
                    case ' ':
                    case '\t':
                        if (!instring)
                        {
                        case '\n':
                        case 0:
                            *d = 0; // terminate argument
                            goto Lnextarg;
                        }
                        goto default;
                    default:
                    Ladd:
                        if (c == '\\')
                            num_slashes++;
                        else
                            num_slashes = 0;
                        *d++ = c;
                        break;
                    }
                }
                break;
            }
        Lnextarg:
        }
    L2:
    }
    if (recurse)
    {
        /* Recursively expand @filename   */
        if (response_expand(args))
            goto noexpand;
    }
    return false; /* success         */
noexpand:
    /* error         */
    /* BUG: any file buffers are not free'd   */
    return true;
}
