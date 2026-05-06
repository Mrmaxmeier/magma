#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

if [ ! -d "$FUZZER/repo" ]; then
    echo "fetch.sh must be executed first."
    exit 1
fi

export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse
export LIBAFL_EDGES_MAP_SIZE=2621440

cd "$FUZZER/repo/fuzzers/fuzzbench"
PATH="$HOME/.cargo/bin:$PATH" cargo build --release
clang-15 -c stub_rt.c
ar r "$OUT/stub_rt.a" stub_rt.o
