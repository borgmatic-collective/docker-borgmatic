#!/bin/bash
# Trigger a Redis BGSAVE and wait for it to finish before borgmatic runs.
#
# Requires:
#   - DOCKERCLI=true in your borgmatic container environment
#   - /var/run/docker.sock:/var/run/docker.sock mounted
#   - Redis container reachable by name via the Docker socket
#
# Redis supports live backups via BGSAVE — there is no need to stop the
# container. BGSAVE forks a child process that writes a point-in-time
# snapshot to dump.rdb. Once this script exits, borgmatic will back up
# the .rdb file as part of its normal source directories sweep.
#
# Make sure the Redis data directory is included in your borgmatic config:
#
#   source_directories:
#       - /mnt/source/redis   # wherever dump.rdb lives on the host
#
# And mount it into the borgmatic container:
#
#   volumes:
#       - /opt/docker/mystack/redis/data:/mnt/source/redis:ro
#
# Wire this up as a before:everything hook in your borgmatic config:
#
#   commands:
#     - before: everything
#       run:
#           - /borgscripts/redis-backup.sh

# ---- configuration -------------------------------------------------------

REDIS_CONTAINER="redis"   # name or ID of the Redis container
WAIT_TIMEOUT=120          # max seconds to wait for BGSAVE to finish

# --------------------------------------------------------------------------

set -euo pipefail

echo "[redis-backup] Triggering BGSAVE on container '${REDIS_CONTAINER}'..."
docker exec "${REDIS_CONTAINER}" redis-cli BGSAVE

echo "[redis-backup] Waiting for BGSAVE to complete (timeout: ${WAIT_TIMEOUT}s)..."
elapsed=0
while [ "${elapsed}" -lt "${WAIT_TIMEOUT}" ]; do
    in_progress=$(docker exec "${REDIS_CONTAINER}" redis-cli INFO persistence \
        | grep 'rdb_bgsave_in_progress' | tr -d '[:space:]' | cut -d: -f2)
    if [ "${in_progress}" = "0" ]; then
        echo "[redis-backup] BGSAVE complete."
        exit 0
    fi
    sleep 2
    elapsed=$((elapsed + 2))
done

echo "[redis-backup] ERROR: BGSAVE did not complete within ${WAIT_TIMEOUT}s." >&2
exit 1
