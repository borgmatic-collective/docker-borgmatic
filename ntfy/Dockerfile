FROM alpine:3.13 as builder
LABEL mainainer='b3vis'
RUN apk upgrade --no-cache \
    && apk add --no-cache \
    alpine-sdk \
    python3-dev \
    py3-pip \
    openssl-dev \
    libffi-dev \
    && pip3 install --upgrade pip \
    && pip3 install --upgrade ntfy[pid,emoji,xmpp,telegram,instapush,slack,rocketchat]

FROM b3vis/borgmatic:v1.1.16-1.5.14
LABEL mainainer='b3vis'
VOLUME /root/.config/ntfy
COPY --from=builder /usr/lib/python3.8/site-packages /usr/lib/python3.8/
COPY --from=builder /usr/bin/ntfy /usr/bin/
