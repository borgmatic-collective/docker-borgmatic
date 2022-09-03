FROM alpine:3.16 as builder
LABEL mainainer='b3vis'
RUN apk upgrade --no-cache \
    && apk add --no-cache \
    alpine-sdk \
    python3-dev \
    py3-pip \
    openssl-dev \
    libffi-dev \
    && pip3 install --upgrade pip \
    && pip3 install --upgrade ntfy[pid,emoji,telegram,instapush,slack,rocketchat]

FROM b3vis/borgmatic:latest
LABEL mainainer='b3vis'
VOLUME /root/.config/ntfy
COPY --from=builder /usr/lib/python3.10/site-packages /usr/lib/python3.10/
COPY --from=builder /usr/bin/ntfy /usr/bin/
