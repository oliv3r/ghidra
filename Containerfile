# SPDX-License-Identifier: Apache-2.0
#
# Copyright (C) 2022 Olliver Schinagl <oliver@schinagl.nl>

ARG ALPINE_VERSION="stable-slim"
ARG TARGET_ARCH="library"

FROM index.docker.io/${TARGET_ARCH}/debian:${ALPINE_VERSION} AS builder

WORKDIR /src

COPY "." "/src"

RUN apt-get update && apt-get install --yes \
        build-essential \
        default-jdk-headless \
        git \
        gradle \
        unzip \
    && \
    export JAVA_HOME='/usr/lib/jvm/default-java/' && \
    echo 'Updating gradle, as debian ships with an ancient version' && \
    _gradle_wrapper="$(mktemp -d -p "${TMPDIR:-/tmp}" 'graddlewrapper.XXXXXX')" && \
    ( cd "${_gradle_wrapper}" && gradle wrapper --gradle-version '7.4.2' --distribution-type 'bin') && \
    cp -r "${_gradle_wrapper}/"* '.' && \
    rm -f -r "${_gradle_wrapper}" && \
    ./gradlew --init-script 'gradle/support/fetchDependencies.gradle' init && \
    ./gradlew 'buildGhidra' && \
    _ghidra_tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" 'ghidra.XXXXXX')" && \
    unzip -u 'build/dist/ghidra_'*'.zip' -d "${_ghidra_tmp}" && \
    mv "${_ghidra_tmp}/ghidra_"*'_DEV' '/'


# Ghidra server container
ARG TARGET_ARCH="library"

FROM index.docker.io/${TARGET_ARCH}/openjdk:jdk-slim

LABEL maintainer="Olliver Schinagl <oliver@schinagl.nl>"

EXPOSE 13100
EXPOSE 13101
EXPOSE 13102

VOLUME /var/lib/ghidra/repositories
VOLUME /etc/ghidra/

COPY --from=builder "/ghidra" "/usr/share/ghidra/"
COPY "./containerfiles/ghidracheck.sh" "/usr/local/bin/"
COPY "./containerfiles/docker-entrypoint.sh" "/init"

RUN apt-get update && apt-get install --yes tini && \
    rm -f -r '/var/lib/apt/lists/' '/var/cache/apt' && \
    ln -s "/usr/share/ghidra/ghidraRun" '/usr/local/bin/ghidra' && \
    ln -s "/usr/share/ghidra/server/ghidraSvr" '/usr/local/bin/ghidra-server' && \
    'ghidra-server' 'install'


WORKDIR /usr/share/ghidra/

HEALTHCHECK CMD "ghidracheck.sh"

ENTRYPOINT [ "/init" ]
