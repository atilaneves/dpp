#!/bin/bash

set -euo pipefail

dub test --build=unittest-cov --compiler="$DC" -- ~@travis
dub build
bundle exec cucumber --tags ~@wip ~@notravis
