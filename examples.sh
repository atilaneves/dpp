#!/bin/bash

set -euo pipefail

bin/include examples/nanomsg.d_ bin/nanomsg.d
dmd -L-lnanomsg -ofbin/nanomsg bin/nanomsg.d
bin/nanomsg

bin/include examples/curl.d_ bin/curl.d
dmd -L-lcurl -ofbin/curl bin/curl.d
bin/curl

bin/include examples/pthread.d_ bin/pthread.d
dmd -L-lcurl -ofbin/pthread bin/pthread.d
bin/pthread
