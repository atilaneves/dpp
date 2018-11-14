module dpp.sum;


struct Sum(T...) {
    import sumtype: SumType;

    private SumType!T sumType;

    @disable this();

    this(U)(auto ref U u) {
        this.sumType = SumType!T(u);
    }

    auto match(A...)() {
        import sumtype: match;
        return sumType.match!A;
    }
}
