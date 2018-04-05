#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="$SCRIPT_DIR"/../../bin

# shellcheck source=../../bash/funcs.bash
source "$SCRIPT_DIR/../../bash/funcs.bash"

build_dpp

for x in "$SCRIPT_DIR"/*.dpp
do
    filename=$(basename -- "$x")
    name="${filename%.*}"

    if [[ "$name" == "openssl" ]] && [ ! -z "${TRAVIS-}" ]; then
        echo "    Skipping $name for Travis CI"
    else
        echo "Testing runnable $name"
        "$SCRIPT_DIR"/run.sh "$name" > /dev/null
    fi
done
