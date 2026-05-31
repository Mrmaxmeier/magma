#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA:  magma support files
# - env OUT:    artifact dir
# - env CFLAGS/CXXFLAGS: magma instrumentation flags
##

export CC="$FUZZER/repo/afl-clang-fast"
export CXX="$FUZZER/repo/afl-clang-fast++"
export AS="llvm-as"

export LIBS="$LIBS -lc++ -lc++abi $FUZZER/repo/utils/aflpp_driver/libAFLDriver.a"
export CXXFLAGS="$CXXFLAGS -stdlib=libc++"

# AFL-only instrumented version.
(
    export OUT="$OUT/afl"
    export LDFLAGS="$LDFLAGS -L$OUT"
    "$MAGMA/build.sh"
    "$TARGET/build.sh"
)

# CmpLog instrumented version.
(
    export OUT="$OUT/cmplog"
    export LDFLAGS="$LDFLAGS -L$OUT"
    export AFL_LLVM_CMPLOG=1
    "$MAGMA/build.sh"
    "$TARGET/build.sh"
)
