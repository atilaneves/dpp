#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="$SCRIPT_DIR"/../bin

for x in "$SCRIPT_DIR"/compile/*.dpp
do
    "$BIN_DIR"/d++ -c -of/tmp/compile.o "$x"
done

for x in "$SCRIPT_DIR"/run/*.dpp
do
    filename=$(basename -- "$x")
    name="${filename%.*}"
    "$SCRIPT_DIR"/run.sh "$name"
done
