#!/bin/bash

set -euo pipefail

DC="${DC:-dmd}"

dub test --build=unittest-cov --compiler="$DC" -- ~@notravis
dub build --compiler="$DC"

if [[ "$DC" == "dmd" ]]; then
    bundle exec cucumber --tags ~@wip --tags ~@notravis
fi
