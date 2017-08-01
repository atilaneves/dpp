#!/bin/bash

set -euo pipefail

dub run --nodeps -q -c integration --build=unittest
