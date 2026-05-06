#!/bin/bash -e

##
# Pre-requirements:
# - $1: path to test case
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env PROGRAM: name of program to run (should be found in $OUT)
##

export TIMELIMIT=0.3s

source "$MAGMA/sanitizers.sh"
common_sanitizer_options[handle_segv]=0
common_sanitizer_options[handle_sigbus]=0
common_sanitizer_options[handle_abort]=0
common_sanitizer_options[handle_sigfpe]=0
common_sanitizer_options[handle_sigill]=0
address_sanitizer_options[detect_leaks]=0
address_sanitizer_options[malloc_context_size]=0
set_sanitizer_options 0

timeout -s KILL --preserve-status $TIMELIMIT bash -c \
    "'$OUT/$PROGRAM' '$1'"
