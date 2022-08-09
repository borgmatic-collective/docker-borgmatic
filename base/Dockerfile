FROM alpine:3.16.2 as builder
LABEL mainainer='b3vis'
COPY requirements.txt /requirements.txt
# mostly taken from https://github.com/borgbackup/borg/blob/1.1.15/Vagrantfile#L10-L26
RUN apk update && apk add --update --no-cache \
    alpine-sdk \
    linux-headers \
    py3-pkgconfig \
    py3-wheel \
    py3-xxhash \
    libxxhash \
    zstd \
    py3-setuptools \
    py3-pip \
    python3-dev \
    openssl-dev \
    lz4-dev \
    acl-dev \
    fuse-dev \
    attr-dev \
    zlib-dev \
    bzip2-dev \
    ncurses-dev \
    readline-dev \
    xz-dev \
    sqlite-dev \
    libffi-dev \
    && python3 -m pip install --no-cache-dir -U pip setuptools wheel

RUN python3 -m pip install -v --no-cache-dir -U -r requirements.txt

FROM alpine:3.16.2
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
    bash \
    bash-completion \
    && rm -rf /var/cache/apk/*
VOLUME /mnt/source
VOLUME /mnt/borg-repository
VOLUME /etc/borgmatic.d
VOLUME /root/.borgmatic
VOLUME /root/.config/borg
VOLUME /root/.ssh
VOLUME /root/.cache/borg
COPY --chmod=755 --from=builder /usr/lib/python3.10/site-packages /usr/lib/python3.10/
COPY --chmod=755 --from=builder /usr/bin/borg /usr/bin/
COPY --chmod=755 --from=builder /usr/bin/borgfs /usr/bin/
COPY --chmod=755 --from=builder /usr/bin/borgmatic /usr/bin/
COPY --chmod=755 --from=builder /usr/bin/generate-borgmatic-config /usr/bin/
COPY --chmod=755 --from=builder /usr/bin/upgrade-borgmatic-config /usr/bin/
COPY --chmod=755 --from=builder /usr/bin/validate-borgmatic-config /usr/bin/
COPY --chmod=755 --from=builder /usr/bin/markdown_py /usr/bin/
COPY --chmod=755 --from=builder /usr/bin/normalizer /usr/bin/
COPY --chmod=755 --from=builder /usr/bin/apprise /usr/bin/
RUN borgmatic --bash-completion > /usr/share/bash-completion/completions/borgmatic && echo "source /etc/profile.d/bash_completion.sh" > /root/.bashrc
CMD ["/entry.sh"]
