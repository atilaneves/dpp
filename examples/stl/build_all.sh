mkdir -p build
if [ -z ${DPP_BLACKLIST_HEADERS} ]; then export DPP_BLACKLIST_HEADERS="blacklist_headers.txt"; fi
if [ -z ${DPP_MAP_TYPE_FILE} ]; then export DPP_MAP_TYPE_FILE="remap_types.txt"; fi

set -euxo pipefail

./build_vec.sh
./build_string.sh
./build_var.sh
