##
# Stage: build core magma
##
FROM ubuntu:24.04 AS magma_core

# TODO remove sudo for user "magma" to avoid unwanted priv escalation from
# other attack vectors.

RUN apt-get update && apt-get install -y sudo

## Magma directory hierarchy
# magma_root is relative to the docker-build's working directory
# The Docker image must be built in the root of the magma directory
ARG magma_root=./

## Path variables inside the container
ENV MAGMA_R=/magma
ENV OUT=/magma_out
ENV COV=/magma_cov
ENV SHARED=/magma_shared

ENV CC=/usr/bin/gcc
ENV CXX=/usr/bin/g++
ENV LD=/usr/bin/ld
ENV AR=/usr/bin/ar
ENV AS=/usr/bin/as
ENV NM=/usr/bin/nm
ENV RANLIB=/usr/bin/ranlib

ENV USER_ID=1000
ENV GROUP_ID=1000
RUN mkdir -p /home && \
	groupadd -g ${GROUP_ID} magma && \
	useradd -l -u ${USER_ID} -K UMASK=0000 -d /home -g magma magma && \
	chown magma:magma /home
RUN	echo "magma:amgam" | chpasswd && usermod -a -G sudo magma
RUN echo "magma ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN mkdir -p ${SHARED} ${OUT} ${COV} && \
	chown magma:magma ${SHARED} ${OUT} ${COV} && \
	chmod 744 ${SHARED} ${OUT} ${COV}

ARG magma_path=magma
ENV MAGMA=${MAGMA_R}/${magma_path}
USER root:root
RUN mkdir -p ${MAGMA} && chown magma:magma ${MAGMA}
COPY --chown=magma:magma ${magma_root}/${magma_path} ${MAGMA}/
RUN ${MAGMA}/preinstall.sh
USER magma:magma
RUN ${MAGMA}/prebuild.sh

ARG fuzzer_name
ARG fuzzer_path=fuzzers/${fuzzer_name}
ENV FUZZER=${MAGMA_R}/${fuzzer_path}
USER root:root
RUN mkdir -p ${FUZZER} && chown magma:magma ${FUZZER}
COPY --chown=magma:magma ${magma_root}/${fuzzer_path} ${FUZZER}/
RUN ${FUZZER}/preinstall.sh
USER magma:magma
RUN ${FUZZER}/fetch.sh
RUN ${FUZZER}/build.sh
RUN if [ -f ${FUZZER}/postinstall.sh ]; then /bin/bash ${FUZZER}/postinstall.sh; fi

ARG target_name
ARG target_path=targets/${target_name}
ENV TARGET_NAME=${target_name}
ENV TARGET=${MAGMA_R}/${target_path}
ARG target_version
ENV TARGET_VERSION=${target_version}
USER root:root
RUN mkdir -p ${TARGET} && chown magma:magma ${TARGET}
COPY --chown=magma:magma ${magma_root}/${target_path} ${TARGET}/
RUN ${TARGET}/preinstall.sh
USER magma:magma
RUN ${MAGMA}/fetch_target.sh
RUN ${MAGMA}/apply_patches.sh

## Configuration parameters
ARG isan
ARG harden
ARG canaries
ARG fixes

ARG ISAN_FLAG=${isan:+-DMAGMA_FATAL_CANARIES}
ARG HARDEN_FLAG=${harden:+-DMAGMA_HARDEN_CANARIES}
ARG CANARIES_FLAG=${canaries:+-DMAGMA_ENABLE_CANARIES}
ARG FIXES_FLAG=${fixes:+-DMAGMA_ENABLE_FIXES}
ARG BUILD_FLAGS="-include ${MAGMA}/src/canary.h ${CANARIES_FLAG} ${FIXES_FLAG} ${ISAN_FLAG} ${HARDEN_FLAG} -g -O0"

ENV CFLAGS=${BUILD_FLAGS}
ENV CXXFLAGS=${BUILD_FLAGS}
ENV LIBS="-l:magma.o -lrt"
ENV LDFLAGS="-L${OUT} -g"

ARG source_coverage
ENV SOURCE_COVERAGE=${source_coverage:+1}
ENV SOURCE_COVERAGE_FLAGS=${source_coverage:+"-fprofile-instr-generate -fcoverage-mapping"}

RUN ${FUZZER}/instrument.sh

ENTRYPOINT ["/bin/bash", "-c", "${MAGMA}/run.sh"]


##
# Stage: build magma PoCs
##
FROM ubuntu:24.04 AS magma_pocs

RUN apt-get update && apt-get install -y sudo g++ git

ARG magma_root=./
ARG poc_target_name
ARG poc_target_version
ARG poc_bug
ENV MAGMA_R=/magma
ENV OUT=/magma_out
ENV CC=/usr/bin/gcc
ENV CXX=/usr/bin/g++

# set up user and group
ARG USER_ID=1001
ARG GROUP_ID=1001

RUN mkdir -p /home && \
	groupadd -g ${GROUP_ID} magma && \
	useradd -l -u ${USER_ID} -K UMASK=0000 -d /home -g magma magma && \
	chown magma:magma /home
RUN	echo "magma:amgam" | chpasswd && usermod -a -G sudo magma
RUN echo "magma ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN mkdir -p ${OUT} && chown magma:magma ${OUT} && chmod 744 ${OUT}

# copy over magma source code
ARG magma_path=magma
ENV MAGMA=${MAGMA_R}/${magma_path}

USER root:root
RUN mkdir -p ${MAGMA} && chown magma:magma ${MAGMA}
COPY --chown=magma:magma ${magma_root}/${magma_path} ${MAGMA}/

# build a clean install of the target with a specific bug
ARG target_path=targets/${poc_target_name}
ENV TARGET_NAME=${poc_target_name}
ENV TARGET=${MAGMA_R}/${target_path}
ENV TARGET_VERSION=${poc_target_version}
ENV BUG_PATH=${TARGET}/patches/bugs/${poc_bug}.patch

USER root:root
RUN mkdir -p ${TARGET} && chown magma:magma ${TARGET}
COPY --chown=magma:magma ${magma_root}/${target_path} ${TARGET}/
RUN ${TARGET}/preinstall.sh
RUN ${MAGMA}/fetch_target.sh
RUN ${MAGMA}/apply_patches.sh ${BUG_PATH}
RUN ${TARGET}/build_poc.sh

# copy over the PoC input
ARG CRASH_CONTAINER_PATH=/test/crash_input
ARG CRASH_INPUT_PATH=${magma_root}/${target_path}/pocs/${poc_bug}.crash

COPY --chown=magma:magma ${CRASH_INPUT_PATH} ${CRASH_CONTAINER_PATH}
