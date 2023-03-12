FROM alpine:3.15 as builder
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

FROM ghcr.io/borgmatic-collective/borgmatic:latest
LABEL mainainer='b3vis'
COPY --from=builder /usr/lib/python3.9/site-packages /usr/lib/python3.9/
COPY --from=builder /usr/bin/ntfy /usr/bin/
