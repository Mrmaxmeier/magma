#!/bin/bash -e

##
# Pre-requirements:
# - env TARGET:  target work dir
# - env OUT:     artifact dir (contains afl/$PROGRAM)
# - env SHARED:  shared volume for findings
# - env PROGRAM: name of the target binary
# - env FUZZARGS: optional extra args
# - env LIBAFL_LOD_EXPERIMENT: LOD variant (default: lod). Set to lod-disable
#   for the byte-mutation baseline.
##

trap '' SIGTTIN SIGTTOU

# AFL++ default ASAN_OPTIONS for a clean forkserver run. Forkserver model
# means crashes happen in the child, so we no longer need to disable signal
# handlers for the libafl in-proc handler — they don't apply here.
export ASAN_OPTIONS="abort_on_error=1:detect_leaks=0:malloc_context_size=0:allocator_may_return_null=1:symbolize=0"
export UBSAN_OPTIONS="abort_on_error=1:symbolize=0"

set -x

mkdir -p "$SHARED/findings"

LOD_EXPERIMENT="${LIBAFL_LOD_EXPERIMENT:-lod}"

# Format selection is automatic: --lod-guess scores every registered LOD
# grammar's skeleton against this target's coverage map at startup and picks
# the matching one(s). No per-target grammar hardcoding. To pin a grammar
# manually (e.g. debugging), pass `--lod <name>` via $FUZZARGS — a successful
# guess still overrides it, so also drop --lod-guess by setting
# LIBAFL_LOD_GUESS=0.
LOD_GUESS_FLAG="--lod-guess"
[ "${LIBAFL_LOD_GUESS:-1}" = "0" ] && LOD_GUESS_FLAG=""

FUZZER_BIN="$FUZZER/lod-sketch/magma-forkserver/target/release/fuzzbench_lod_forkserver"

cd "$SHARED"

# AFL++ runtime knobs. We let aflpp_driver pick its own map size (libpng's
# real edge count is ~4544; oversized AFL_MAP_SIZE breaks the seed-load path)
# and let the deferred forkserver run so init coverage isn't double-counted.
export AFL_SKIP_CPUFREQ=1
export AFL_NO_AFFINITY=1

# aflpp_driver requires argv[1] to pick the input source ("-" for stdin, "@@"
# resolved to a temp file by ForkserverExecutor, etc.). Magma per-target
# configrc files set ${PROGRAM}_ARGS — captain exports that as ARGS. Default
# to "-" when unset (libpng_read_fuzzer / tiff_read_rgba_fuzzer pattern).
TARGET_ARGS="${ARGS:--}"

"$FUZZER_BIN" \
    -i "$TARGET/corpus/$PROGRAM" \
    -o "$SHARED/findings" \
    --logfile "$SHARED/libafl.log" \
    --experiment "$LOD_EXPERIMENT" \
    $LOD_GUESS_FLAG \
    $FUZZARGS \
    -- "$OUT/afl/$PROGRAM" $TARGET_ARGS
