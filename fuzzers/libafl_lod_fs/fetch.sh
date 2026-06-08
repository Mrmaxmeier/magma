#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - $FUZZER/sources/ pre-populated by sync.sh on the host (rsynced into the
#   docker context). No network clones for our sources; aflplusplus is pulled
#   from upstream at a pinned commit.
##

if [ ! -d "$FUZZER/sources/lod-sketch" ]; then
    echo "fetch.sh: expected vendored sources under \$FUZZER/sources/ — run sync.sh on the host first." >&2
    exit 1
fi

mv "$FUZZER/sources/lod-sketch" "$FUZZER/lod-sketch"
rmdir "$FUZZER/sources"

# AFLplusplus provides afl-clang-fast + aflpp_driver/libAFLDriver.a, which we
# use to instrument the magma target. Pinned to the same commit magma's stock
# aflplusplus integration uses.
mkdir -m 0700 -p ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --no-checkout https://github.com/AFLplusplus/AFLplusplus "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 458eb0813a6f7d63eed97f18696bca8274533123

# Same aflpp_driver patches magma's stock aflplusplus integration applies.
sed -i '{s/^int main/__attribute__((weak)) &/}' \
    "$FUZZER/repo/utils/aflpp_driver/aflpp_driver.c"
sed -i '{s/^int LLVMFuzzerTestOneInput/__attribute__((weak)) &/}' \
    "$FUZZER/repo/utils/aflpp_driver/aflpp_driver.c"
cat >> "$FUZZER/repo/utils/aflpp_driver/aflpp_driver.c" << 'EOF'
__attribute__((weak))
int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size)
{
  return 0;
}
EOF

patch -p1 -d "$FUZZER/repo" << 'EOF'
--- a/utils/aflpp_driver/aflpp_driver.c
+++ b/utils/aflpp_driver/aflpp_driver.c
@@ -53,7 +53,7 @@
   #include "hash.h"
 #endif

-int                   __afl_sharedmem_fuzzing = 1;
+int                   __afl_sharedmem_fuzzing = 0;
 extern unsigned int * __afl_fuzz_len;
 extern unsigned char *__afl_fuzz_ptr;

@@ -111,7 +111,8 @@ extern unsigned int * __afl_fuzz_len;
 __attribute__((weak)) int LLVMFuzzerInitialize(int *argc, char ***argv);

 // Notify AFL about persistent mode.
-static volatile char AFL_PERSISTENT[] = "##SIG_AFL_PERSISTENT##";
+// DISABLED to avoid afl-showmap misbehavior
+static volatile char AFL_PERSISTENT[] = "##SIG_AFL_NOT_PERSISTENT##";
 int                  __afl_persistent_loop(unsigned int);

 // Notify AFL about deferred forkserver.
EOF
