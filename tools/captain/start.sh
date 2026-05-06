#!/bin/bash -e

##
# Pre-requirements:
# - env FUZZER: fuzzer name (from fuzzers/)
# - env TARGET: target name (from targets/)
# - env PROGRAM: program name (name of binary artifact from $TARGET/build.sh)
# - env ARGS: program launch arguments
# - env FUZZARGS: fuzzer arguments
# - env POLL: time (in seconds) between polls
# - env TIMEOUT: time to run the campaign
# + env SHARED: path to host-local volume where fuzzer findings are saved
#       (default: no shared volume)
# + env AFFINITY: the CPU to bind the container to (default: no affinity)
# + env ENTRYPOINT: a custom entry point to launch in the container (default:
#       $MAGMA/run.sh)
##

cleanup() {
    if [ ! -t 1 ]; then
        podman rm -f $container_id &> /dev/null
    fi
    exit 0
}

trap cleanup EXIT SIGINT SIGTERM

if [ -z $FUZZER ] || [ -z $TARGET ] || [ -z $PROGRAM ]; then
    echo '$FUZZER, $TARGET, and $PROGRAM must be specified as' \
         'environment variables.'
    exit 1
fi

MAGMA=${MAGMA:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" >/dev/null 2>&1 \
    && pwd)"}
export MAGMA
source "$MAGMA/tools/captain/common.sh"

IMG_NAME="magma/$FUZZER/$TARGET"

cpuset_supported_for_current_cgroup() {
    local cgroup_path controllers_file controllers
    cgroup_path="$(awk -F: '$1 == "0" { print $3 }' /proc/self/cgroup)"
    [ -z "$cgroup_path" ] && cgroup_path="/"
    controllers_file="/sys/fs/cgroup${cgroup_path}/cgroup.controllers"
    [ ! -r "$controllers_file" ] && return 1

    read -r controllers < "$controllers_file"
    [[ " $controllers " == *" cpuset "* ]]
}

if [ ! -z $AFFINITY ]; then
    flag_aff="--env=AFFINITY=$AFFINITY"
    if cpuset_supported_for_current_cgroup; then
        flag_aff="--cpuset-cpus=$AFFINITY $flag_aff"
    else
        echo_time "cpuset controller unavailable; skipping --cpuset-cpus for Podman"
    fi
fi

if [ ! -z "$MAGMA_DEBUG" ]; then
    echo_time "Old entrypoint: $ENTRYPOINT"
    ENTRYPOINT="/bin/bash"
    echo_time "New entrypoint: $ENTRYPOINT"
fi

if [ ! -z "$ENTRYPOINT" ]; then
    flag_ep="--entrypoint=$ENTRYPOINT"
fi

if [ ! -z "$SHARED" ]; then
    SHARED="$(realpath "$SHARED")"
    flag_volume="--volume=$SHARED:/magma_shared"
fi


if [ ! -z "$MAGMA_DEBUG" ]; then
    flag_volume+=" --volume=$MAGMA/magma:/magma/magma"
    flag_volume+=" --volume=$MAGMA/fuzzers/$FUZZER:/magma/fuzzers/$FUZZER/workdir"
    flag_volume+=" --volume=$MAGMA/targets/$TARGET:/magma/targets/$TARGET/workdir"
fi

if [ -t 1 ]; then
    podman run -it --rm $flag_volume \
        --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
        --env=PROGRAM="$PROGRAM" --env=ARGS="$ARGS" \
        --env=FUZZARGS="$FUZZARGS" --env=POLL="$POLL" --env=TIMEOUT="$TIMEOUT" \
        $flag_aff $flag_ep "$IMG_NAME"
else
    container_id=$(
    podman run -dt $flag_volume \
        --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
        --env=PROGRAM="$PROGRAM" --env=ARGS="$ARGS" \
        --env=FUZZARGS="$FUZZARGS" --env=POLL="$POLL" --env=TIMEOUT="$TIMEOUT" \
        --network=none \
        $flag_aff $flag_ep "$IMG_NAME"
    )
    container_id=$(cut -c-12 <<< $container_id)
    echo_time "Container for $FUZZER/$TARGET/$PROGRAM started in $container_id"
    podman logs -f "$container_id" &
    exit_code=$(podman wait $container_id)
    exit $exit_code
fi
