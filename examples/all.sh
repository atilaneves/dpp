#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="$SCRIPT_DIR"/../bin

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
