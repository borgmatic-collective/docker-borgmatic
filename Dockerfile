# syntax = docker/dockerfile:latest

FROM python:3.13.3-alpine3.21 AS base
ARG TARGETARCH

LABEL maintainer='borgmatic-collective'

FROM base AS base-amd64
ENV S6_OVERLAY_ARCH=x86_64

FROM base AS base-arm64
ENV S6_OVERLAY_ARCH=aarch64

FROM base-${TARGETARCH}${TARGETVARIANT}

ARG S6_OVERLAY_VERSION=3.2.0.2

# Add S6 Overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz /tmp/s6-overlay.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp

# Add S6 optional symlinks
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-noarch.tar.xz /tmp
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-symlinks-arch.tar.xz /tmp

ENV LANG='en_US.UTF-8'                   \
    LANGUAGE='en_US.UTF-8'               \
    TERM='xterm'                         \
    S6_LOGGING="1"                       \
    S6_VERBOSITY="0"                     \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
    TZ="Europe/London"

RUN <<EOF
    set -xe
    apk upgrade --update --no-cache
    tar -C / -Jxpf /tmp/s6-overlay.tar.xz
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
    tar -C / -Jxpf /tmp/s6-overlay-symlinks-noarch.tar.xz
    tar -C / -Jxpf /tmp/s6-overlay-symlinks-arch.tar.xz

    apk add --no-cache -U   \
        bash                \
        bash-completion     \
        bash-doc            \
        btrfs-progs         \
        ca-certificates     \
        curl                \
        findmnt             \
        fuse                \
        acl-libs            \
        libxxhash           \
        logrotate           \
        lz4-libs            \
        mariadb-client      \
        mariadb-connector-c \
        mongodb-tools       \
        openssl             \
        postgresql-client   \
        pkgconfig           \
        sshfs               \
        sqlite              \
        tzdata              \
        xxhash
    apk upgrade --no-cache
EOF

COPY --link requirements.txt /

RUN --mount=type=cache,id=pip,target=/root/.cache,sharing=locked \
    <<EOF
    set -xe
    python3 -m pip install -U pip
    python3 -m pip install -Ur requirements.txt
    apk add --no-cache -U borgmatic-bash-completion
EOF

COPY --chmod=744 --link root/ /

VOLUME /root/.local/state/borgmatic
VOLUME /root/.config/borg
VOLUME /root/.cache/borg

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 CMD borgmatic config validate

ENTRYPOINT [ "/init" ]
