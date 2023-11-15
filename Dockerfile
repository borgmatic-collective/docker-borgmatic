# syntax = docker/dockerfile:latest
FROM python:3.11.5-alpine3.18
LABEL maintainer='github.com/borgmatic-collective'
# VOLUME /mnt/source
# VOLUME /mnt/borg-repository
# VOLUME /root/.borgmatic
# VOLUME /etc/borgmatic.d
# VOLUME /root/.config/borg
# VOLUME /root/.ssh
# VOLUME /root/.cache/borg
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
    msmtp \
    && rm -rf \
    /var/cache/apk/* \
    /.cache

COPY --chmod=755 entry.sh /entry.sh
COPY requirements.txt /
COPY Bengel+CA.crt /usr/local/share/ca-certificates/bengelca.crt

RUN python3 -m pip install --no-cache -Ur requirements.txt
RUN borgmatic --bash-completion > /usr/share/bash-completion/completions/borgmatic && echo "source /etc/bash/bash_completion.sh" > /root/.bashrc

RUN mkdir /root/.ssh \
    && touch /root/.ssh/config \
    && echo "StrictHostKeyChecking=accept-new" | tee /root/.ssh/config \
    && ln -sf /usr/bin/msmtp /usr/sbin/sendmail \
    && update-ca-certificates

ENTRYPOINT ["/entry.sh"]
