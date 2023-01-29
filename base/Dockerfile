# syntax = docker/dockerfile:latest
FROM golang:1.19.3-alpine3.17 AS gobuilder
ARG SUPERCRONIC_VERSION="v0.2.1"
RUN apk add --no-cache git
RUN go install github.com/aptible/supercronic@"${SUPERCRONIC_VERSION}"

FROM python:3.11.1-alpine3.17
LABEL maintainer='b3vis'
VOLUME /mnt/source
VOLUME /mnt/borg-repository
VOLUME /root/.borgmatic
VOLUME /etc/borgmatic.d
VOLUME /root/.config/borg
VOLUME /root/.ssh
VOLUME /root/.cache/borg
RUN apk add --update --no-cache \
    tzdata \
    sshfs \
    openssl1.1-compat \
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

COPY --from=gobuilder /go/bin/supercronic /usr/local/bin/
COPY --chmod=755 entry.sh /entry.sh
COPY --link requirements.txt /

RUN python3 -m pip install --no-cache -Ur requirements.txt
RUN borgmatic --bash-completion > /usr/share/bash-completion/completions/borgmatic && echo "source /etc/profile.d/bash_completion.sh" > /root/.bashrc

CMD ["/entry.sh"]
