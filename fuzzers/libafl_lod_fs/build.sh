#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env OUT:    where build artifacts land
#
# Builds:
#  1. AFLplusplus (afl-clang-fast + aflpp_driver/libAFLDriver.a)
#  2. fuzzbench_lod_forkserver (the libafl-based forkserver fuzzer)
##

if [ ! -d "$FUZZER/repo" ] || [ ! -d "$FUZZER/lod-sketch" ]; then
    echo "build.sh: fetch.sh must run first." >&2
    exit 1
fi

# --- 1. AFLplusplus ----------------------------------------------------------
cd "$FUZZER/repo"
export CC=clang
export CXX=clang++
export AFL_NO_X86=1
export PYTHON_INCLUDE=/
make -j"$(nproc)"
make -C utils/aflpp_driver

mkdir -p "$OUT/afl" "$OUT/cmplog"

# --- 2. fuzzbench_lod_forkserver --------------------------------------------
# Lives inside lod-sketch now; libafl is pulled from crates.io by cargo.
FUZZBENCH_LOD_FS="$FUZZER/lod-sketch/magma-forkserver"
if [ ! -d "$FUZZBENCH_LOD_FS" ]; then
    echo "build.sh: missing $FUZZBENCH_LOD_FS — vendored sources are stale?" >&2
    exit 1
fi

export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse
cd "$FUZZBENCH_LOD_FS"
PATH="$HOME/.cargo/bin:$PATH" cargo build --release
