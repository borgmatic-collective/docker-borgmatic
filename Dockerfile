# syntax = docker/dockerfile:latest

ARG ALPINE_VERSION=3.24
ARG PYTHON_VERSION=3.14

FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION} AS base
ARG TARGETARCH

LABEL maintainer='modem7'

FROM base AS base-amd64
ENV S6_OVERLAY_ARCH=x86_64

FROM base AS base-arm64
ENV S6_OVERLAY_ARCH=aarch64

# hadolint ignore=DL3006
FROM base-${TARGETARCH}${TARGETVARIANT}

ARG S6_OVERLAY_VERSION=3.2.3.0

ENV LANG='en_US.UTF-8'                      \
    LANGUAGE='en_US.UTF-8'                  \
    S6_LOGGING="1"                          \
    S6_VERBOSITY="0"                        \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0"     \
    TZ="Europe/London"

# Install system packages first — this layer is independent of S6 and borgmatic
# versions, so it stays cached across S6 bumps and requirements.txt changes.
# hadolint ignore=DL3005,DL3018,DL3019,DL3059
RUN --mount=type=cache,id=apk-${TARGETARCH},target=/etc/apk/cache \
    apk upgrade -U && \
    apk add -U          \
        bash            \
        bash-completion \
        btrfs-progs     \
        ca-certificates \
        curl            \
        findmnt         \
        fuse            \
        acl-libs        \
        libxxhash       \
        logrotate       \
        lz4-libs        \
        mariadb-client      \
        mariadb-connector-c \
        mongodb-tools       \
        openssl             \
        postgresql-client   \
        sshfs               \
        sqlite              \
        tzdata              \
        xxhash

# hadolint ignore=DL3059
# Add S6 Overlay — separate layer so S6 bumps don't invalidate the apk layer
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp/s6-overlay.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp

# hadolint ignore=DL3059
RUN <<EOF
    set -xe
    tar -C / -Jxpf /tmp/s6-overlay.tar.xz
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
    tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
    tar -C / -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz
    rm -rf /tmp/*.tar.xz
EOF

COPY --link requirements.txt /

# hadolint ignore=DL3013,DL3018,DL3042
RUN --mount=type=cache,id=pip,target=/root/.cache,sharing=locked \
    <<EOF
    set -xe
    python3 -m pip install -U pip
    python3 -m pip install -Ur requirements.txt
    apk add --no-cache -U borgmatic-bash-completion
    mv /usr/local/bin/borgmatic /usr/local/bin/borgmatic.bin
EOF

COPY --chmod=744 --link root/ /

VOLUME /root/.local/state/borgmatic
VOLUME /root/.config/borg
VOLUME /root/.cache/borg

ENTRYPOINT [ "/init" ]
