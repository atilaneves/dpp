int main(string[] args) {

    import dpp.runtime: run, Options;
    import std.stdio: stderr;

    try {
        const options = Options(args);
        if(options.earlyExit) return 0;
        run(options);
        return 0;
    } catch(Exception ex) {
        stderr.writeln(ex);
        return 1;
    } catch(Throwable t) {
        stderr.writeln("Fatal error: ", t);
        return 2;
    }
}
