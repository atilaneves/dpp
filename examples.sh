#!/bin/bash

set -euo pipefail

bin/include example/nanomsg.d_ bin/nanomsg.d
dmd -ofbin/nanomsg.o -c bin/nanomsg.d

bin/include example/curl.d_ bin/curl.d
dmd -ofbin/curl.o -c bin/curl.d
