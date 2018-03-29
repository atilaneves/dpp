#!/bin/bash

set -euo pipefail

./example.sh nanomsg
./example.sh curl
./example.sh pthread
./example.sh stdlib
