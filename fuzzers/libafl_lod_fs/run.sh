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

# Per-target grammar map. Auto-guess is not wired in this forkserver port (it
# would require running the target out-of-process to score each candidate
# grammar's dummy bytes — doable but not v1).
LOD_FLAGS_libpng_read_fuzzer="--lod png"
LOD_FLAGS_tiff_read_rgba_fuzzer="--lod tiff"
LOD_FLAGS_tiffcp="--lod tiff"
LOD_FLAGS_sndfile_fuzzer="--lod ogg --lod flac --lod wav_chunk"
LOD_FLAGS_libxml2_xml_read_memory_fuzzer="--lod xml"
LOD_FLAGS_var="LOD_FLAGS_$PROGRAM"
LOD_FLAGS="${!LOD_FLAGS_var:-}"

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
    $LOD_FLAGS \
    $FUZZARGS \
    -- "$OUT/afl/$PROGRAM" $TARGET_ARGS
