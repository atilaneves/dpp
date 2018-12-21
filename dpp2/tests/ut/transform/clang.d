/**
   Tests that we're using libclang properly.
 */
module ut.transform.clang;


import ut;
import dpp2.expansion;
import dpp.runtime.options: Options;
import dpp.runtime.context: Context, Language;


@("includePaths")
@safe pure unittest {
    {
        Options options;
        options.includePaths = ["foo", "bar"];
        includePaths(options, "dir/app.dpp").should == ["foo", "bar", "dir"];
        includePaths(options, "other/app.dpp").should == ["foo", "bar", "other"];
    }

    {
        Options options;
        options.includePaths = ["quux"];
        includePaths(options, "dir/app.dpp").should == ["quux", "dir"];
        includePaths(options, "other/app.dpp").should == ["quux", "other"];
    }
}


@("clangArgs.c.0")
@safe pure unittest {
    Options options;
    options.includePaths = ["foo", "bar"];
    options.defines = ["quux", "toto"];
    Context context;
    context.options = options;

    clangArgs(context, "dir/app.dpp").shouldBeSameSetAs(
        ["-Ifoo", "-Ibar", "-Idir", "-Dquux", "-Dtoto", "-xc"]);
}


@("clangArgs.c.1")
@safe pure unittest {
    Options options;
    options.includePaths = ["fizz"];
    options.defines = ["oops"];
    Context context;
    context.options = options;

    clangArgs(context, "other/app.dpp").shouldBeSameSetAs(
        ["-Ifizz", "-Iother", "-Doops", "-xc"]);
}


@("clangArgs.cpp.parseAsCpp")
@safe pure unittest {
    Options options;
    options.includePaths = ["fizz"];
    options.defines = ["oops"];
    options.parseAsCpp = true;
    Context context;
    context.options = options;

    clangArgs(context, "other/app.dpp").shouldBeSameSetAs(
        ["-Ifizz", "-Iother", "-Doops", "-xc++", "-std=c++14"]);
}

@("clangArgs.cpp.language")
@safe pure unittest {
    Options options;
    options.includePaths = ["fizz"];
    options.defines = ["oops"];
    Context context;
    context.options = options;
    context.language = Language.Cpp;

    clangArgs(context, "other/app.dpp").shouldBeSameSetAs(
        ["-Ifizz", "-Iother", "-Doops", "-xc++", "-std=c++14"]);
}


@("getHeaderName")
@safe pure unittest {
    import unit_threaded: shouldEqual;
    getHeaderName(`#include "foo.h"`).shouldEqual(`foo.h`);
    getHeaderName(`#include "bar.h"`).shouldEqual(`bar.h`);
    getHeaderName(`#include "foo.h" // comment`).shouldEqual(`foo.h`);
    getHeaderName(`#include <foo.h>`).shouldEqual(`foo.h`);
    getHeaderName(`    #include "foo.h"`).shouldEqual(`foo.h`);
}
