if [ -z ${DPP_BLACKLIST_HEADERS} ]; then
	export DPP_BLACKLIST_HEADERS="blacklist_headers.txt";
fi

if [ -z ${DPP_BLACKLIST_FUNCTIONS_FILE} ]; then
	export DPP_BLACKLIST_FUNCTIONS="blacklist_functions.txt";
fi

if [ -z ${DPP_MAP_TYPE_FILE} ]; then
	export DPP_MAP_TYPE_FILE="remap_types.txt";
fi

set -euxo pipefail
clang++ -c vec/v.cpp -o build/v.o
d++ 	--parse-as-cpp \
	--c++-std-lib \
	--keep-d-files \
	--map-type-file $DPP_MAP_TYPE_FILE \
	--blacklist-header-file $DPP_BLACKLIST_HEADERS \
	--blacklist-function-file $DPP_BLACKLIST_FUNCTIONS \
	-ofbin/vec \
	-Ivec/ \
	vec/app.dpp \
	build/v.o

