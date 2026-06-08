#!/bin/bash

##
# Pre-requirements:
# - env TARGET:  target work dir
# - env OUT:     artifact dir (contains the in-process fuzzer at $OUT/$PROGRAM)
# - env SHARED:  shared volume for findings
# - env PROGRAM: name of the target binary
# - env FUZZARGS: optional extra args
# - env LIBAFL_LOD_EXPERIMENT: LOD variant (default: lod). Set to lod-disable
#   for the byte-mutation baseline.
#
# Unlike libafl_lod_fs, the target binary IS the fuzzer (in-process). We invoke
# $OUT/$PROGRAM directly with -i/-o; there is no `-- target` subprocess.
##

trap '' SIGTTIN SIGTTOU

# libafl's in-process crash handler must catch crashes itself, so the
# sanitizers must NOT install their own signal handlers.
export ASAN_OPTIONS="abort_on_error=1:detect_leaks=0:malloc_context_size=0:allocator_may_return_null=1:symbolize=0:handle_segv=0:handle_sigbus=0:handle_abort=0:handle_sigfpe=0:handle_sigill=0"
export UBSAN_OPTIONS="abort_on_error=1:symbolize=0:handle_segv=0:handle_sigbus=0:handle_sigfpe=0:handle_sigill=0"

set -x

mkdir -p "$SHARED/findings"

LOD_EXPERIMENT="${LIBAFL_LOD_EXPERIMENT:-lod}"

# Format selection. In-process coverage probing is fragile (a crashing skeleton
# aborts the whole process), so guessing is OFF by default here — pin a grammar
# with $FUZZARGS="--lod <name>" or env LOD_GRAMMAR. Set LIBAFL_LOD_GUESS=1 to
# opt into probing anyway.
LOD_GUESS_FLAG=""
[ "${LIBAFL_LOD_GUESS:-0}" = "1" ] && LOD_GUESS_FLAG="--lod-guess"

cd "$SHARED"

# Pre-create the magma canary storage ($SHARED/canaries.raw) at its full size
# before the fuzzer runs. The magma entrypoint starts its monitor loop (which
# lazily O_CREATs + ftruncates this file) concurrently with us; without this,
# the in-process target's very first canary write can race the monitor's
# create+truncate and fault on a still-zero-length mapping, killing the whole
# campaign at startup. `monitor --dump` creates and zeroes the file idempotently.
"$OUT/monitor" --dump row >/dev/null 2>&1 || true

# Resilient relaunch loop. The in-process libafl restarting manager can die
# under a high crash rate — magma canaries turn many inputs into "crashes", and
# on crash-heavy targets (libsndfile, libpng) the broker/restart machinery
# occasionally tears down the whole process after a burst of rapid restarts. If
# that happens we relaunch and RESUME from the persisted -o corpus, so the
# campaign keeps fuzzing for the full TIMEOUT instead of dying early (which would
# bias the lod-vs-disable comparison). The magma entrypoint wraps us in
# `timeout $TIMEOUT`; that SIGTERM is trapped here and propagated to the child so
# the campaign ends promptly at the deadline (not relaunched).
#
# The in-process fuzzer reads testcases from memory; it takes no target args.
child=""
on_term() { [ -n "$child" ] && kill -TERM "$child" 2>/dev/null; exit 0; }
trap on_term TERM INT

while true; do
    "$OUT/$PROGRAM" \
        -i "$TARGET/corpus/$PROGRAM" \
        -o "$SHARED/findings" \
        --logfile "$SHARED/libafl.log" \
        --experiment "$LOD_EXPERIMENT" \
        $LOD_GUESS_FLAG \
        $FUZZARGS &
    child=$!
    wait "$child" || true   # returns on fuzzer exit OR via the TERM trap
    # Reached only when the fuzzer ended on its own (crash/manager death):
    # relaunch and resume from $SHARED/findings. The TERM trap exits directly.
    echo "[run.sh] fuzzer exited unexpectedly; relaunching (resume) at $(date '+%F %T')"
    sleep 1
done
