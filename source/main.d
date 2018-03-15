int main(string[] args) {

    import include.runtime: run, Options;
    import std.stdio: stderr;

    try {
        run(Options(args));
        return 0;
    } catch(Exception ex) {
        stderr.writeln("Error: ", ex);
        return 1;
    } catch(Throwable t) {
        stderr.writeln("Fatal error: ", t);
        return 2;
    }
}
