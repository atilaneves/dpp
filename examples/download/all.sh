#!/bin/bash

# This script downloads some open source C libraries
# And tests compiling example .dpp files that #include them

set -euo pipefail


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPOS_DIR="$SCRIPT_DIR"/repos
BIN_DIR="$SCRIPT_DIR"/../../bin


git_clone() {
    git clone --recursive "$1" --depth=1 --branch master
}

mk() {
    make -j"$(nproc)"
}

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd > /dev/null
}


[[ -e "$REPOS_DIR" ]] || mkdir "$REPOS_DIR"

pushd "$REPOS_DIR"

[[ -e "$REPOS_DIR"/libxlsxwriter ]] || git_clone git@github.com:jmcnamara/libxlsxwriter.git
[[ -e "$REPOS_DIR"/libetpan ]] || git_clone git@github.com:dinhviethoa/libetpan.git
[[ -e "$REPOS_DIR"/imapfilter ]] || git_clone git@github.com:lefcha/imapfilter.git
[[ -e "$REPOS_DIR"/libvirt ]] || git_clone git@github.com:libvirt/libvirt.git
[[ -e "$REPOS_DIR"/zfs ]] || git_clone git@github.com:zfsonlinux/zfs.git

if [[ ! -e "$REPOS_DIR"/libetpan/include/libetpan ]]; then
    pushd "$REPOS_DIR"/libetpan
    ./autogen.sh
    mk
    popd
    if [[ ! -e "$REPOS_DIR"/libetpan/include/libetpan ]]; then
        echo "ERROR: no libetpan"
        exit 1
    fi
fi

if [[ ! -e "$REPOS_DIR"/libvirt/config.h ]]; then
    pushd "$REPOS_DIR"/libvirt
    ./autogen.sh
    popd
    if [[ ! -e "$REPOS_DIR"/libvirt/config.h ]]; then
        echo "ERROR no config.h for libvirt"
        exit 1
    fi
fi
popd



echo Testing download libxlsxwriter
"$BIN_DIR"/d++ --clang-include-path "$REPOS_DIR"/libxlsxwriter/include "$SCRIPT_DIR"/anatomy.dpp -c

echo Testing download zfs
"$BIN_DIR"/d++ --clang-include-path "$REPOS_DIR"/zfs/include --clang-include-path "$REPOS_DIR"/zfs/lib/libspl/include "$SCRIPT_DIR"/zfs.dpp -c

# echo Testing download etpan
# # FIXME
# "$BIN_DIR"/d++ --clang-include-path "$REPOS_DIR"/libetpan/include "$SCRIPT_DIR"/etpan.dpp -c

echo Testing download libvirt
"$BIN_DIR"/d++ --clang-include-path "$REPOS_DIR"/libvirt --clang-include-path "$REPOS_DIR"/libvirt/include "$SCRIPT_DIR"/virt.dpp -c

echo Testing download imapfilter
"$BIN_DIR"/d++ --clang-include-path "$REPOS_DIR"/imapfilter/src "$SCRIPT_DIR"/imap.dpp -c
