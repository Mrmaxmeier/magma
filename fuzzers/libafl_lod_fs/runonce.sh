#!/bin/bash -e

##
# Pre-requirements:
# - $1: path to test case
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env PROGRAM: name of program to run (should be found in $OUT/afl)
#
# magma/run.sh calls this once per seed before launching the fuzzer to prune
# crash-on-load seeds. Our target binary is the AFL-instrumented version under
# $OUT/afl/$PROGRAM, and it reads input from stdin (aflpp_driver, `-` arg) or
# from argv[1] as a file path. Pass the seed path directly.
##

export TIMELIMIT=0.3s

# Sanitizer options the magma sanitizers.sh helper would set if it were
# shipped in this checkout. Mirrors the libafl/runonce.sh recipe.
export ASAN_OPTIONS="abort_on_error=1:handle_segv=0:handle_sigbus=0:handle_abort=0:handle_sigfpe=0:handle_sigill=0:detect_leaks=0:malloc_context_size=0:allocator_may_return_null=1:symbolize=0"
export UBSAN_OPTIONS="abort_on_error=1:handle_segv=0:handle_sigbus=0:handle_abort=0:handle_sigfpe=0:handle_sigill=0:symbolize=0"

# Pass through per-program $ARGS (e.g. tiffcp's "-M @@ tmp.out") so seeds get
# validated with the same invocation the fuzzer will use. If $ARGS is unset,
# default to passing the seed path directly (the libpng/libtiff_rgba pattern
# with aflpp_driver, where argv[1] is the input file).
if [ -z "${ARGS:-}" ]; then
    timeout -s KILL --preserve-status $TIMELIMIT bash -c \
        "'$OUT/afl/$PROGRAM' '$1'"
else
    # $ARGS embeds @@ as the input-file placeholder.
    expanded_args="${ARGS//@@/$1}"
    timeout -s KILL --preserve-status $TIMELIMIT bash -c \
        "'$OUT/afl/$PROGRAM' $expanded_args"
fi
