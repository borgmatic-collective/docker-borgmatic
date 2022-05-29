FROM alpine:3.15 as builder
LABEL mainainer='b3vis'
COPY requirements.txt /requirements.txt
RUN apk upgrade --no-cache \
    && apk add --no-cache \
    alpine-sdk \
    python3-dev \
    py3-pip \
    py3-pkgconfig \
    openssl-dev \
    lz4-dev \
    acl-dev \
    linux-headers \
    fuse-dev \
    attr-dev \
    py3-wheel \
    && pip3 install --no-cache-dir -U -r requirements.txt

FROM alpine:3.15
LABEL mainainer='b3vis'
COPY --chmod=755 entry.sh /entry.sh
RUN apk upgrade --no-cache \
    && apk add --no-cache \
    tzdata \
    sshfs \
    python3 \
    openssl \
    fuse \
    ca-certificates \
    lz4-libs \
    libacl \
    postgresql-client \
    mariadb-client \
    mongodb-tools \
    curl \
    findmnt \
    logrotate \
    && rm -rf /var/cache/apk/*
VOLUME /mnt/source
VOLUME /mnt/borg-repository
VOLUME /etc/borgmatic.d
VOLUME /root/.borgmatic
VOLUME /root/.config/borg
VOLUME /root/.ssh
VOLUME /root/.cache/borg
COPY --from=builder /usr/lib/python3.9/site-packages /usr/lib/python3.9/
COPY --from=builder /usr/bin/borg /usr/bin/
COPY --from=builder /usr/bin/borgfs /usr/bin/
COPY --from=builder /usr/bin/borgmatic /usr/bin/
COPY --from=builder /usr/bin/generate-borgmatic-config /usr/bin/
COPY --from=builder /usr/bin/upgrade-borgmatic-config /usr/bin/
COPY --from=builder /usr/bin/validate-borgmatic-config /usr/bin/
CMD ["/entry.sh"]
