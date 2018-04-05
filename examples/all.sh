#!/bin/bash

# Check all the examples work

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="$SCRIPT_DIR"/../bin

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

# Files that should compile with no dependencies
for x in "$SCRIPT_DIR"/compile/*.dpp
do
    echo "Testing compileable $x"
    "$BIN_DIR"/d++ -c -of/tmp/compile.o "$x"
done

# Files that should run with no dependencies
for x in "$SCRIPT_DIR"/run/*.dpp
do
    filename=$(basename -- "$x")
    name="${filename%.*}"
    echo "Testing runnable $x"
    "$SCRIPT_DIR"/run.sh "$name" > /dev/null
done

# Files that need downloaded dependencies
"$SCRIPT_DIR"/download/all.sh
