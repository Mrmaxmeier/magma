#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA:  magma support files
# - env OUT:    artifact dir
# - env CFLAGS/CXXFLAGS: magma instrumentation flags
#
# Compiles the magma target IN-PROCESS: the magma-inproc libafl_cc/cxx wrappers
# instrument it with SanitizerCoverage (edges + cmp) and link it against
# libmagma_inproc.a (auto, via the wrapper) + stub_rt.a, producing a single
# self-contained fuzzer binary at $OUT/$PROGRAM. There is no separate
# afl / cmplog build — cmplog is compiled in via trace-cmp.
##

REL="$FUZZER/lod-sketch/target/release"
export CC="$REL/libafl_cc"
export CXX="$REL/libafl_cxx"

# The wrapper *always* injects `-fsanitize-coverage=trace-pc-guard,trace-cmp`
# (see libafl_cc.rs), so target+harness are instrumented for edges+cmp coverage.
#
# NO ASAN. Magma's bug oracle is its canaries (compiled in via -include canary.h),
# not AddressSanitizer, and the in-process libafl handler catches SIGSEGV/SIGABRT
# on its own — so asan adds nothing here but instability: an asan-instrumented
# autoconf `configure` conftest intermittently segfaults at startup in this build
# container (shadow-memory/ASLR flakiness), failing the build nondeterministically
# ("cannot run C compiled programs"). The proven local in-process harness
# (local_tiff_inproc) is likewise no-ASAN.
#
# We also deliberately do NOT pass `--libafl`. With it the wrapper force-links
# (whole-archive) libmagma_inproc.a into EVERY link — including conftests — so a
# conftest's instrumented comparison calls libafl's real cmplog handler against a
# not-yet-initialised map and segfaults ("cannot compute sizeof"). Instead the
# engine goes in LIBS for on-demand resolution (like the stock libfuzzer fuzzer's
# libFuzzer.a): a conftest (own `main`, no `libafl_main` ref) pulls only the
# self-contained weak sancov stubs and runs clean; the real fuzzer (no `main`)
# pulls stub_main.o -> libafl_main -> libmagma, whose strong sancov/cmplog defs
# override the weak stubs.
export CXXFLAGS="$CXXFLAGS -stdlib=libc++"
export LDFLAGS="$LDFLAGS -L$REL"

# libsndfile (and other oss-fuzz `--enable-ossfuzzers` targets) pick their fuzzing
# engine from LIB_FUZZING_ENGINE: if it names a file, that archive is linked as the
# engine (USE_OSSFUZZ_STATIC); otherwise they fall back to a "standalone engine"
# whose own `main` reads files from argv — which would shadow our libafl entry and
# make the binary not fuzz at all. Point it at stub_rt.a (carries main->libafl_main);
# libmagma_inproc.a is still pulled via LIBS. Unused by targets that link the
# harness by hand (libpng, libtiff).
export LIB_FUZZING_ENGINE="$OUT/stub_rt.a"

# Belt-and-suspenders for libsndfile: its configure runs AX_COMPILER_VERSION,
# which computes __clang_minor__ via a run-conftest; pre-seed the cache var so
# that probe is skipped. Harmless/unused for targets that don't use the macro.
export ax_cv_c_compiler_version="15.0.7"

# Weak sancov stubs for configure/cmake compiler tests (no `main` — that lives in
# stub_rt.a / LIB_FUZZING_ENGINE). The real runtime resolves on demand for the
# final fuzzer link.
export LIBS="$LIBS -lc++ -lc++abi $OUT/stub_sancov.a -lmagma_inproc"

# Single instrumented build straight into $OUT (no afl/ or cmplog/ subdirs).
"$MAGMA/build.sh"
"$TARGET/build.sh" || { echo "=== DEBUG config.log (run-test section) ==="; \
    sed -n '/configure:.*checking whether we are cross/,/## Cache variables/p' "$TARGET/repo/config.log" 2>/dev/null; \
    echo "=== END config.log ==="; exit 77; }
