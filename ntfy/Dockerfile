FROM alpine:latest as builder
MAINTAINER b3vis
ARG BORG_VERSION=1.1.10
ARG BORGMATIC_VERSION=1.4.21
RUN apk upgrade --no-cache \
    && apk add --no-cache \
    alpine-sdk \
    python3-dev \
    openssl-dev \
    linux-headers \
    # Below this line are requirements for ntfy
    libffi-dev \
    && pip3 install --upgrade pip \
    && pip3 install --upgrade ntfy[pid,emoji,xmpp,telegram,instapush,slack,rocketchat]

FROM b3vis/borgmatic:v1.1.10-1.4.21
MAINTAINER b3vis
VOLUME /root/.config/ntfy
COPY --from=builder /usr/lib/python3.8/site-packages /usr/lib/python3.8/
COPY --from=builder /usr/bin/ntfy /usr/bin/