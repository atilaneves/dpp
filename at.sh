#!/bin/bash

# Run all acceptance tests

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="$SCRIPT_DIR"/bin

# shellcheck source=bash/funcs.bash
source "$SCRIPT_DIR/bash/funcs.bash"

clear
build_dpp
bundle exec cucumber --tags ~@wip
./examples/all.sh
