FROM alpine:3.16.1 as builder
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

FROM alpine:3.16.1
LABEL mainainer='b3vis'
ARG PYTHON_VERSION=3.10
VOLUME /mnt/source
VOLUME /mnt/borg-repository
VOLUME /root/.borgmatic
VOLUME /etc/borgmatic.d
VOLUME /root/.config/borg
VOLUME /root/.ssh
VOLUME /root/.cache/borg
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 CMD borgmatic --version || exit 1
RUN apk add --update --no-cache \
    tzdata \
    sshfs \
    python3 \
    openssl \
    libxxhash \
    zstd \
    fuse \
    ca-certificates \
    logrotate \
    lz4-libs \
    libacl \
    postgresql-client \
    mariadb-client \
    mongodb-tools \
    curl \
    findmnt \
    bash \
    bash-completion \
    bash-doc \
    && rm -rf \
    /var/cache/apk/* \
    /.cache
COPY --from=builder /usr/lib/python${PYTHON_VERSION}/site-packages /usr/lib/python${PYTHON_VERSION}/
COPY --chmod=755 --from=builder \ 
     /usr/bin/borg \
     /usr/bin/borgfs \
     /usr/bin/borgmatic \
     /usr/bin/generate-borgmatic-config \
     /usr/bin/upgrade-borgmatic-config \
     /usr/bin/validate-borgmatic-config \
     /usr/bin/markdown_py \
     /usr/bin/normalizer \
     /usr/bin/apprise \
     /usr/bin/
COPY --chmod=755 entry.sh /entry.sh
RUN borgmatic --bash-completion > /usr/share/bash-completion/completions/borgmatic && echo "source /etc/profile.d/bash_completion.sh" > /root/.bashrc
CMD ["/entry.sh"]
