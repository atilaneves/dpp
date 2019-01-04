if [ -z ${DPP_BLACKLIST_HEADERS} ]; then
	export DPP_BLACKLIST_HEADERS="blacklist_headers.txt";
fi

if [ -z ${DPP_MAP_TYPE_FILE} ]; then
	export DPP_MAP_TYPE_FILE="remap_types.txt";
fi

set -euxo pipefail

clang++ -c -o build/stlstringcpp.o str/stlstringcpp.cpp
d++ 	--include-path str/ \
	--parse-as-cpp \
	--c++-std-lib \
	--keep-d-files \
	--map-type-file $DPP_MAP_TYPE_FILE \
	--blacklist-header-file $DPP_BLACKLIST_HEADERS \
	-ofbin/str \
	-Istr/ \
	str/stlstring.dpp \
	build/stlstringcpp.o \
	-L-lstdc++
