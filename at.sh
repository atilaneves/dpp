#!/bin/bash

set -euo pipefail

./examples.sh
bundle exec cucumber --tags ~@wip
