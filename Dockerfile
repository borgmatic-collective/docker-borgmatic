# syntax = docker/dockerfile:latest
FROM python:3.11.2-alpine3.17
LABEL maintainer='github.com/borgmatic-collective'
VOLUME /mnt/source
VOLUME /mnt/borg-repository
VOLUME /root/.borgmatic
VOLUME /etc/borgmatic.d
VOLUME /root/.config/borg
VOLUME /root/.ssh
VOLUME /root/.cache/borg
RUN apk add --update --no-cache \
    bash \
    bash-completion \
    bash-doc \
    ca-certificates \
    curl \
    findmnt \
    fuse \
    libacl \
    logrotate \
    lz4-libs \
    mariadb-client \
    mariadb-connector-c \
    mongodb-tools \
    openssl1.1-compat \
    postgresql-client \
    sqlite \
    sshfs \
    supercronic \
    tzdata \
    && rm -rf \
    /var/cache/apk/* \
    /.cache

COPY --chmod=755 entry.sh /entry.sh
COPY requirements.txt /

RUN python3 -m pip install --no-cache -Ur requirements.txt
RUN borgmatic --bash-completion > /usr/share/bash-completion/completions/borgmatic && echo "source /etc/profile.d/bash_completion.sh" > /root/.bashrc

ENTRYPOINT ["/entry.sh"]
