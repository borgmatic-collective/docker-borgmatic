FROM alpine:latest
MAINTAINER b3vis
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
    && pip3 install --upgrade borgbackup \
    && pip3 install --upgrade borgmatic \
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
