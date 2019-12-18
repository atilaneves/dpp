#!/bin/bash

set -euo pipefail

DC="${DC:-dmd}"

dub test -q --build=unittest-cov --compiler="$DC" --registry=http://31.15.67.41
# dub run -q -c dpp2 --build=unittest --compiler="$DC"
dub build -q --compiler="$DC" --registry=http://31.15.67.41

if [[ "$DC" == "dmd" ]]; then
    bundle exec cucumber --tags ~@wip
fi
