FROM python:3.9-slim as compiler
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq \
    && apt-get install -qq \
    build-essential \
    libfuse-dev fuse \
    libssl-dev libacl1-dev libxxhash-dev libdeflate-dev liblz4-dev libzstd-dev pkg-config \
    locales

RUN pip3 install --no-cache-dir -U pip==22.1.1 \
    && pip3 install --no-cache-dir -U llfuse==1.4.1 \
    && pip3 install --no-cache-dir -U pkgconfig==1.5.5 \
    && pip3 install --no-cache-dir -U borgbackup==1.2.0 \
    && pip3 install --no-cache-dir -U borgmatic==1.6.1

FROM python:3.9-slim
RUN apt-get update -qq \
    && apt-get install -qq \
    tzdata \
    sshfs \
    openssl \
    fuse \
    ca-certificates \
    liblz4-1 \
    libacl1 \
    postgresql-client \
    mariadb-client \
    curl \
    util-linux \
    logrotate \
    && rm -rf /var/lib/apt/lists/*
    # missing: mongodb-tools \
COPY --from=compiler /usr/lib/python3.9/site-packages /usr/lib/python3.9/
COPY --from=compiler /usr/bin/borg /usr/bin/
COPY --from=compiler /usr/bin/borgfs /usr/bin/
COPY --from=compiler /usr/bin/borgmatic /usr/bin/
COPY --from=compiler /usr/bin/generate-borgmatic-config /usr/bin/
COPY --from=compiler /usr/bin/upgrade-borgmatic-config /usr/bin/
COPY --from=compiler /usr/bin/validate-borgmatic-config /usr/bin/