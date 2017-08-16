FROM alpine:latest
MAINTAINER b3vis
COPY entry.sh /entry.sh
RUN apk upgrade --no-cache \
    && apk add --no-cache \
    curl \
    sshfs \
    python3 \
    py3-msgpack \
    ca-certificates \
    openssl-dev \
    lz4-dev \
    musl-dev \
    gcc \
    python3-dev \
    acl-dev \
    && pip3 install --upgrade pip \
    && pip3 install --upgrade borgbackup \
    && pip3 install --upgrade borgmatic \
    && mkdir /config /cache /source /repository \
    && rm -rf /var/cache/apk/* \
    && chmod 755 /entry.sh
VOLUME /config
VOLUME /cache
VOLUME /source
VOLUME /repository
# Set Envars
ENV BORG_CACHE_DIR /cache
CMD ["/entry.sh"]
