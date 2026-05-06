#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

mkdir -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --no-checkout https://github.com/vusec/LibAFL-directed "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 870af0263e9f7b25b029da42f5617765c3e72863 

cd "$FUZZER/repo"
sed -i '30c\
            .silence(env::var("LIBAFL_CC_VERBOSE").is_err())\
            // Honor -O0 flag\
            .dont_optimize()
' fuzzers/fuzzbench/src/bin/libafl_cc.rs
