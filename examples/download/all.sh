#!/bin/bash

# This script downloads some open source C libraries
# And tests compiling example .dpp files that #include them

set -euo pipefail


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPOS_DIR="$SCRIPT_DIR"/repos
BIN_DIR="$SCRIPT_DIR"/../../bin

# shellcheck source=../../bash/funcs.bash
source "$SCRIPT_DIR/../../bash/funcs.bash"

build_dpp

[[ -e "$REPOS_DIR" ]] || mkdir "$REPOS_DIR"

pushd "$REPOS_DIR"

[[ -e "$REPOS_DIR"/libxlsxwriter ]] || git_clone git@github.com:jmcnamara/libxlsxwriter.git
[[ -e "$REPOS_DIR"/libetpan ]] || git_clone git@github.com:dinhviethoa/libetpan.git
[[ -e "$REPOS_DIR"/imapfilter ]] || git_clone git@github.com:lefcha/imapfilter.git
[[ -e "$REPOS_DIR"/libvirt ]] || git_clone git@github.com:libvirt/libvirt.git
[[ -e "$REPOS_DIR"/zfs ]] || git_clone git@github.com:zfsonlinux/zfs.git
[[ -e "$REPOS_DIR"/nanomsg ]] || git_clone git@github.com:nanomsg/nanomsg.git


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

dpp() {
"$BIN_DIR"/d++ --keep-d-files "$@"
}

echo Testing download etpan
dpp --include-path "$REPOS_DIR"/libetpan/include "$SCRIPT_DIR"/etpan.dpp -c

echo Testing download nanomsg
dpp --include-path "$REPOS_DIR" "$SCRIPT_DIR"/nanomsg.dpp -L-lnanomsg -of/tmp/nanomsg -checkaction=context
/tmp/nanomsg

echo Testing download libxlsxwriter
dpp --include-path "$REPOS_DIR"/libxlsxwriter/include "$SCRIPT_DIR"/anatomy.dpp -c

echo Testing download zfs
dpp --include-path "$REPOS_DIR"/zfs/include --include-path "$REPOS_DIR"/zfs/lib/libspl/include "$SCRIPT_DIR"/zfs.dpp -c

echo Testing download libvirt
dpp --include-path "$REPOS_DIR"/libvirt --include-path "$REPOS_DIR"/libvirt/include "$SCRIPT_DIR"/virt.dpp -c

if [ ! -z "${TRAVIS-}" ]; then
    echo "    Skipping imapfilter for Travis CI"
else
    echo Testing download imapfilter
    dpp --include-path "$REPOS_DIR"/imapfilter/src "$SCRIPT_DIR"/imap.dpp -c
fi
