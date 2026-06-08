#!/bin/bash
set -e

##
# Host-side staging script for the libafl_lod_inproc fuzzer.
#
# The lod-sketch sources are a local checkout (not git-cloneable from inside the
# Docker build), so we copy them into this fuzzer's directory *before* building
# the image. The docker build context is the magma root, so anything under
# fuzzers/libafl_lod_inproc/sources/ gets COPYed into the image, where fetch.sh
# relocates it to $FUZZER/lod-sketch.
#
# Run this on the host whenever the lod-sketch sources change, before
# `tools/captain/build.sh` (or `docker build`).
#
# Override the source location with LOD_SRC=/path/to/lod-sketch.
##

LOD_SRC="${LOD_SRC:-$HOME/patlang-rs/lod-sketch}"
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sources/lod-sketch"

if [ ! -d "$LOD_SRC" ]; then
    echo "sync.sh: lod-sketch sources not found at '$LOD_SRC'." >&2
    echo "         Set LOD_SRC=/path/to/lod-sketch and retry." >&2
    exit 1
fi

if [ ! -f "$LOD_SRC/magma-inproc/Cargo.toml" ]; then
    echo "sync.sh: '$LOD_SRC' doesn't look like lod-sketch" \
         "(missing magma-inproc/Cargo.toml)." >&2
    exit 1
fi

mkdir -p "$DST"

# --delete keeps the staged copy in lockstep with the source. Skip build
# artifacts (target/) and VCS metadata — they bloat the docker context and
# aren't needed for the cargo build (Cargo.lock is committed, so deps pin).
rsync -a --delete \
    --exclude='target/' \
    --exclude='.git/' \
    "$LOD_SRC/" "$DST/"

echo "sync.sh: staged $LOD_SRC -> $DST"
