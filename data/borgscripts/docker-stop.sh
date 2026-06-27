#!/bin/bash
# Stop containers that carry the backup label before a borgmatic run.
#
# Requires:
#   - DOCKERCLI=true in your borgmatic container environment
#   - /var/run/docker.sock:/var/run/docker.sock mounted
#
# Label the services you want paused in their own compose files:
#
#   services:
#     myapp:
#       labels:
#         - backup
#
# The label approach avoids hardcoding container names and automatically
# includes any new services you add the label to in the future.
# --no-run-if-empty prevents an error when no labelled containers are running.

# ---- configuration -------------------------------------------------------

BACKUP_LABEL="backup"   # label key applied to services that should pause
STOP_TIMEOUT=60         # seconds to wait for graceful shutdown before force-kill

# --------------------------------------------------------------------------

set -euo pipefail

echo "[docker-stop] Stopping containers with label '${BACKUP_LABEL}'..."
docker ps -q -f "label=${BACKUP_LABEL}" \
  | xargs --no-run-if-empty docker container stop -t "${STOP_TIMEOUT}"
echo "[docker-stop] Done."
