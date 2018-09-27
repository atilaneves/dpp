#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="$SCRIPT_DIR"/../../bin

"$BIN_DIR"/d++ --hard-fail -of"$BIN_DIR/$1" "$SCRIPT_DIR/$1.dpp" -L-lcurl
"$BIN_DIR/$1"
