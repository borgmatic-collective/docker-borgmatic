FROM b3vis/borgmatic:latest
LABEL mainainer='b3vis'
COPY entry.sh /entry.sh
COPY data/scripts /scripts
RUN chmod +x /scripts/*
COPY data/borgmatic.d /etc/borgmatic.d
RUN apk upgrade --no-cache \
    && apk add --no-cache \
    msmtp \
    && ln -sf /usr/bin/msmtp /usr/sbin/sendmail \
    && rm -rf /var/cache/apk/* \
    && chmod 755 /entry.sh
