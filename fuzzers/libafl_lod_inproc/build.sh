#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env OUT:    where build artifacts land
#
# Builds the in-process LOD fuzzer toolchain:
#  1. magma-inproc staticlib + libafl_cc/libafl_cxx wrappers (cargo)
#  2. stub_rt.a  (process main -> libafl_main + weak sancov fallbacks)
#
# Unlike libafl_lod_fs there is no AFLplusplus build: the wrappers do the
# instrumentation and the target is linked into the fuzzer in instrument.sh.
##

if [ ! -d "$FUZZER/lod-sketch" ]; then
    echo "build.sh: fetch.sh must run first." >&2
    exit 1
fi

LOD_SKETCH="$FUZZER/lod-sketch"
INPROC="$LOD_SKETCH/magma-inproc"
if [ ! -d "$INPROC" ]; then
    echo "build.sh: missing $INPROC — vendored sources are stale?" >&2
    exit 1
fi

export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse
# Bake the same large edges-map size the magma targets need into the sancov
# runtime compiled into the staticlib.
export LIBAFL_EDGES_MAP_SIZE=2621440
# libafl_cc's build.rs compiles the CmpLog/AutoTokens LLVM pass plugins against
# this llvm-config. On ubuntu:24.04 (noble) that's the distro's llvm-18 (see
# preinstall.sh); pin it so the build doesn't pick up some other PATH llvm-config.
export LLVM_CONFIG="${LLVM_CONFIG:-/usr/bin/llvm-config-18}"

# lod-sketch is a cargo workspace: artifacts land in $LOD_SKETCH/target/release,
# not magma-inproc/target/release.
cd "$LOD_SKETCH"
PATH="$HOME/.cargo/bin:$PATH" cargo build --release -p magma-inproc

# Two archives:
#   stub_sancov.a — weak sancov/cmplog stubs only (safe in LIBS / cmake tests)
#   stub_rt.a     — stubs + `main` -> libafl_main (fuzzing engine)
STUB_NMAIN="$OUT/stub_rt_no_main.c"
awk '/^int main\(/{exit} {print}' "$INPROC/stub_rt.c" > "$STUB_NMAIN"
clang -O3 -c "$STUB_NMAIN" -o "$OUT/stub_sancov.o"
clang -O3 -c "$INPROC/stub_rt.c" -o "$OUT/stub_rt.o"
ar rcs "$OUT/stub_sancov.a" "$OUT/stub_sancov.o"
ar rcs "$OUT/stub_rt.a" "$OUT/stub_sancov.o" "$OUT/stub_rt.o"
rm -f "$STUB_NMAIN" "$OUT/stub_sancov.o" "$OUT/stub_rt.o"
