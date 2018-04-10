#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="$SCRIPT_DIR"/../../bin

# shellcheck source=../../bash/funcs.bash
source "$SCRIPT_DIR/../../bash/funcs.bash"

build_dpp

for x in "$SCRIPT_DIR"/*.dpp
do
    echo "Testing compileable $x"
    "$BIN_DIR"/d++ --keep-pre-cpp-file -c -of/tmp/compile.o "$x"
done
