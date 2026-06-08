#!/bin/bash
set -ex

##
# Toolchain for the in-process libafl LOD fuzzer:
#  - clang/LLVM (recent): the magma-inproc libafl_cc/cxx wrappers wrap `clang`
#    and need a matching LLVM for the SanitizerCoverage + CmpLog passes.
#  - rust stable: cargo build of the magma-inproc staticlib + wrappers.
#
# No clang-9 / afl-clang-fast here — there is no AFLplusplus instrumentation in
# the in-process path.
##

export DEBIAN_FRONTEND=noninteractive

apt-get update && \
    apt-get install -y make build-essential git wget curl \
        gnupg lsb-release software-properties-common \
        libc++-dev libc++abi-dev

# Recent clang/LLVM for the wrapper passes. ubuntu:24.04 (noble) ships clang +
# llvm 18 in its own repos; apt.llvm.org has NO llvm-15 channel for noble (404),
# so use the distro packages. LibAFL 0.15's CmpLog/AutoTokens pass plugins build
# against LLVM 18, and llvm-18-dev provides the headers + llvm-config-18 that
# libafl_cc's build.rs needs to compile them.
apt-get install -y clang-18 lld-18 llvm-18 llvm-18-dev libclang-18-dev
update-alternatives \
  --install /usr/bin/clang       clang       /usr/bin/clang-18       20 \
  --slave   /usr/bin/clang++     clang++     /usr/bin/clang++-18 \
  --slave   /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-18

apt-get clean -y

# Rust toolchain for the cargo build of the magma-inproc staticlib. The magma
# user's home is /home; build.sh looks for the toolchain under $HOME/.cargo.
MAGMA_HOME="${MAGMA_HOME:-/home}"
curl https://sh.rustup.rs \
    | sudo -u magma HOME="$MAGMA_HOME" \
        sh -s -- -y --profile minimal --default-toolchain stable
