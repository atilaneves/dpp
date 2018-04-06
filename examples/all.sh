#!/bin/bash

# Check all the examples work

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="$SCRIPT_DIR"/../bin

# shellcheck source=../bash/funcs.bash
source "$SCRIPT_DIR/../bash/funcs.bash"

clear
build_dpp
echo

# Files that should compile with no dependencies
"$SCRIPT_DIR"/compile/all.sh
echo

# Files that should run with no dependencies
"$SCRIPT_DIR"/run/all.sh
echo

# Files that need downloaded dependencies
"$SCRIPT_DIR"/download/all.sh
echo
