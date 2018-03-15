#!/bin/bash

set -euo pipefail

bin/include example/nanomsg.d_ bin/nanomsg.d
dmd -L-lnanomsg -ofbin/nanomsg bin/nanomsg.d

bin/include example/curl.d_ bin/curl.d
dmd -L-lcurl -ofbin/curl bin/curl.d
