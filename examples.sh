#!/bin/bash

set -euo pipefail

for x in examples/*.dpp
do
    filename=$(basename -- "$x")
    name="${filename%.*}"
    ./example.sh "$name"
done
