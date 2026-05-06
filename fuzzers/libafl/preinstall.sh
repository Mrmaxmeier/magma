#!/bin/bash
set -ex

export DEBIAN_FRONTEND=noninteractive

apt-get update && \
    apt-get install -y git wget curl \
                       gnupg lsb-release software-properties-common

alias curl="curl --proto '=https' --tlsv1.2 -sSf"

add-apt-repository -y ppa:ubuntu-toolchain-r/test

curl -O https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
./llvm.sh 15
rm -f llvm.sh

apt-get clean -y

curl https://sh.rustup.rs \
    | sudo -u magma HOME="$MAGMA_HOME" \
        sh -s -- -y --profile minimal --default-toolchain 1.90
