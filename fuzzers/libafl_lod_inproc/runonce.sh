#!/bin/bash -e

##
# Pre-requirements:
# - $1: path to test case
# - env OUT: path to directory where artifacts are stored
# - env PROGRAM: name of program to run (the in-process fuzzer at $OUT/$PROGRAM)
#
# magma/run.sh calls this once per seed to prune crash-on-load seeds. The
# in-process fuzzer doubles as a libfuzzer-style reproducer: passing testcase
# paths as positional args replays them through LLVMFuzzerTestOneInput and exits.
##

export TIMELIMIT=0.3s

export ASAN_OPTIONS="abort_on_error=1:handle_segv=0:handle_sigbus=0:handle_abort=0:handle_sigfpe=0:handle_sigill=0:detect_leaks=0:malloc_context_size=0:allocator_may_return_null=1:symbolize=0"
export UBSAN_OPTIONS="abort_on_error=1:handle_segv=0:handle_sigbus=0:handle_sigfpe=0:handle_sigill=0:symbolize=0"

timeout -s KILL --preserve-status $TIMELIMIT bash -c \
    "'$OUT/$PROGRAM' '$1'"
