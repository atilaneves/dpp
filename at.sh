#!/bin/bash

# Run all acceptance tests

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="$SCRIPT_DIR"/bin

# just to shut it up
pushd () {
    command pushd "$@" > /dev/null
}

# just to shut it up
popd () {
    command popd > /dev/null
}

# Build an up-to-date binary
if [[ -e "$BIN_DIR"/build.ninja ]]; then
    ninja -C "$BIN_DIR" d++ > /dev/null
else
    pushd "$SCRIPT_DIR/.."
    dub build
    popd
fi

bundle exec cucumber --tags ~@wip
./examples/all.sh
