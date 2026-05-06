#!/bin/bash -e

##
# Pre-requirements:
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env SHARED: path to directory shared with host (to store results)
# - env PROGRAM: name of program to run (should be found in $OUT)
# - env FUZZARGS: extra arguments to pass to the fuzzer
##

trap '' SIGTTIN SIGTTOU

#source "$MAGMA/sanitizers.sh"
#common_sanitizer_options[handle_segv]=0
#common_sanitizer_options[handle_sigbus]=0
#common_sanitizer_options[handle_abort]=0
#common_sanitizer_options[handle_sigfpe]=0
#common_sanitizer_options[handle_sigill]=0
#address_sanitizer_options[detect_leaks]=0
#address_sanitizer_options[malloc_context_size]=0
#set_sanitizer_options 1
#echo "\
#+ ASAN_OPTIONS=$ASAN_OPTIONS
#+ UBSAN_OPTIONS=$UBSAN_OPTIONS" >&2
set -x

mkdir -p "$SHARED/findings"

"$OUT/$PROGRAM" \
    -i "$TARGET/corpus/$PROGRAM" \
    -o "$SHARED/findings" \
    $FUZZARGS
