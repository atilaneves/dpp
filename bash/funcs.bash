# just to shut it up
pushd () {
    command pushd "$@" > /dev/null
}

# just to shut it up
popd () {
    command popd > /dev/null
}

git_clone() {
    git clone --recursive "$1" --depth=1 --branch master
}

mk() {
    make -j"$(nproc)"
}

# Build an up-to-date binary
build_dpp () {
    if [[ -e "$BIN_DIR"/build.ninja ]]; then
        ninja -C "$BIN_DIR" d++ > /dev/null
    else
        pushd "$SCRIPT_DIR/.." || exit 1
        dub build
        popd || exit 1
    fi
}
