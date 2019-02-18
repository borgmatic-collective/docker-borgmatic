FROM alpine:latest
MAINTAINER b3vis

ARG BORG_VERSION=1.1.9
ARG BORGMATIC_VERSION=1.2.15

COPY entry.sh /entry.sh
RUN apk upgrade --no-cache \
    && apk add --no-cache \
    alpine-sdk \
    tzdata \
    sshfs \
    python3 \
    python3-dev \
    openssl-dev \
    lz4-dev \
    acl-dev \
    linux-headers \
    fuse-dev \
    attr-dev \
    && pip3 install --upgrade pip \
    && pip3 install --upgrade borgbackup==${BORG_VERSION} \
    && pip3 install --upgrade borgmatic==${BORGMATIC_VERSION} \
    && pip3 install llfuse \
    && mkdir /config /cache /source /repository /root/.ssh \
    && rm -rf /var/cache/apk/* \
    && chmod 755 /entry.sh
VOLUME /config
VOLUME /etc/borgmatic.d
VOLUME /cache
VOLUME /source
VOLUME /repository
VOLUME /root/.ssh
# Set Envars
ENV BORG_CACHE_DIR /cache
CMD ["/entry.sh"]
