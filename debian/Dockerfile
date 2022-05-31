FROM python:3.9-slim as compiler
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    build-essential \
    libfuse-dev fuse \
    libssl-dev libacl1-dev libxxhash-dev libdeflate-dev liblz4-dev libzstd-dev pkg-config \
    locales \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir -U pip==22.1.1
RUN pip3 install --no-cache-dir -U pkgconfig==1.5.5
RUN pip3 install --no-cache-dir -U llfuse==1.4.0
RUN pip3 install --no-cache-dir -U borgbackup==1.2.0
RUN pip3 install --no-cache-dir -U borgmatic==1.6.1

FROM compiler
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
    tzdata \
    sshfs \
    openssl \
    fuse3 \
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
COPY --from=compiler /usr/local/lib/python3.9/site-packages /usr/lib/python3.9/
COPY --from=compiler /usr/local/bin/borg /usr/bin/
COPY --from=compiler /usr/local/bin/borgfs /usr/bin/
COPY --from=compiler /usr/local/bin/borgmatic /usr/bin/
COPY --from=compiler /usr/local/bin/generate-borgmatic-config /usr/bin/
COPY --from=compiler /usr/local/bin/upgrade-borgmatic-config /usr/bin/
COPY --from=compiler /usr/local/bin/validate-borgmatic-config /usr/bin/
