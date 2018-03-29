#!/bin/bash

set -euo pipefail

bin/include "examples/$1.d_" "bin/$1.d"
dmd "-ofbin/$1" "bin/$1.d" -L-lcurl -L-lnanomsg
"bin/$1"
