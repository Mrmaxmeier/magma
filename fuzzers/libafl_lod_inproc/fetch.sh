#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - $FUZZER/sources/ pre-populated by sync.sh on the host (rsynced into the
#   docker context). No network clones for our sources.
#
# Unlike libafl_lod_fs, the in-process fuzzer needs NO AFLplusplus checkout:
# instrumentation is done by the magma-inproc libafl_cc/cxx wrappers, and there
# is no separate target subprocess / aflpp_driver.
##

if [ ! -d "$FUZZER/sources/lod-sketch" ]; then
    echo "fetch.sh: expected vendored sources under \$FUZZER/sources/ — run sync.sh on the host first." >&2
    exit 1
fi

mv "$FUZZER/sources/lod-sketch" "$FUZZER/lod-sketch"
rmdir "$FUZZER/sources"
