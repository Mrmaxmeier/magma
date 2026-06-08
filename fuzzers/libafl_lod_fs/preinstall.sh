#!/bin/bash
set -ex

##
# Union of magma/fuzzers/libafl (rust 1.90 + clang-15) and aflplusplus
# (clang-9 + LLVM-9 for afl-clang-fast). Both are needed:
#  - clang-9: afl-clang-fast LLVM passes for AFL++ instrumentation
#  - clang-15: required by some recent libafl-side headers
#  - rust 1.90: cargo build of fuzzbench_lod_forkserver
##

export DEBIAN_FRONTEND=noninteractive

apt-get update && \
    apt-get install -y make clang-9 llvm-9-dev libc++-9-dev libc++abi-9-dev \
        build-essential git wget gcc-7-plugin-dev curl \
        gnupg lsb-release software-properties-common

update-alternatives \
  --install /usr/lib/llvm              llvm             /usr/lib/llvm-9  20 \
  --slave   /usr/bin/llvm-config       llvm-config      /usr/bin/llvm-config-9  \
    --slave   /usr/bin/llvm-ar           llvm-ar          /usr/bin/llvm-ar-9 \
    --slave   /usr/bin/llvm-as           llvm-as          /usr/bin/llvm-as-9 \
    --slave   /usr/bin/llvm-bcanalyzer   llvm-bcanalyzer  /usr/bin/llvm-bcanalyzer-9 \
    --slave   /usr/bin/llvm-c-test       llvm-c-test      /usr/bin/llvm-c-test-9 \
    --slave   /usr/bin/llvm-cov          llvm-cov         /usr/bin/llvm-cov-9 \
    --slave   /usr/bin/llvm-diff         llvm-diff        /usr/bin/llvm-diff-9 \
    --slave   /usr/bin/llvm-dis          llvm-dis         /usr/bin/llvm-dis-9 \
    --slave   /usr/bin/llvm-dwarfdump    llvm-dwarfdump   /usr/bin/llvm-dwarfdump-9 \
    --slave   /usr/bin/llvm-extract      llvm-extract     /usr/bin/llvm-extract-9 \
    --slave   /usr/bin/llvm-link         llvm-link        /usr/bin/llvm-link-9 \
    --slave   /usr/bin/llvm-mc           llvm-mc          /usr/bin/llvm-mc-9 \
    --slave   /usr/bin/llvm-nm           llvm-nm          /usr/bin/llvm-nm-9 \
    --slave   /usr/bin/llvm-objdump      llvm-objdump     /usr/bin/llvm-objdump-9 \
    --slave   /usr/bin/llvm-ranlib       llvm-ranlib      /usr/bin/llvm-ranlib-9 \
    --slave   /usr/bin/llvm-readobj      llvm-readobj     /usr/bin/llvm-readobj-9 \
    --slave   /usr/bin/llvm-rtdyld       llvm-rtdyld      /usr/bin/llvm-rtdyld-9 \
    --slave   /usr/bin/llvm-size         llvm-size        /usr/bin/llvm-size-9 \
    --slave   /usr/bin/llvm-stress       llvm-stress      /usr/bin/llvm-stress-9 \
    --slave   /usr/bin/llvm-symbolizer   llvm-symbolizer  /usr/bin/llvm-symbolizer-9 \
    --slave   /usr/bin/llvm-tblgen       llvm-tblgen      /usr/bin/llvm-tblgen-9

update-alternatives \
  --install /usr/bin/clang                 clang                  /usr/bin/clang-9     20 \
  --slave   /usr/bin/clang++               clang++                /usr/bin/clang++-9 \
  --slave   /usr/bin/clang-cpp             clang-cpp              /usr/bin/clang-cpp-9

# clang-15 (for any libafl-side cc invocations)
add-apt-repository -y ppa:ubuntu-toolchain-r/test
curl -O https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
./llvm.sh 15
rm -f llvm.sh

apt-get clean -y

# Rust toolchain for the cargo build of fuzzbench_lod_forkserver.
# The magma user's home is /home (Dockerfile `useradd -d /home`), and build.sh
# looks for the toolchain under $HOME/.cargo; default MAGMA_HOME accordingly so
# rustup installs where build.sh expects it.
MAGMA_HOME="${MAGMA_HOME:-/home}"
curl https://sh.rustup.rs \
    | sudo -u magma HOME="$MAGMA_HOME" \
        sh -s -- -y --profile minimal --default-toolchain 1.90
