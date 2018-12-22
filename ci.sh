#!/bin/bash

set -euo pipefail

DC="${DC:-dmd}"

dub test --build=unittest-cov --compiler="$DC"
dub run -c dpp2 --build=unittest --compiler="$DC"
dub build --compiler="$DC"

if [[ "$DC" == "dmd" ]]; then
    bundle exec cucumber --tags ~@wip
fi
