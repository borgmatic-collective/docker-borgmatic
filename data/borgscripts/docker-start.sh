#!/bin/bash
# Start a compose stack after a borgmatic run completes.
#
# Requires:
#   - DOCKERCLI=true in your borgmatic container environment
#   - /var/run/docker.sock:/var/run/docker.sock mounted
#
# Uses `docker compose start` rather than `up -d` to restart only the
# containers that were previously running — it will not recreate, pull,
# or start services that were already stopped before the backup began.
#
# Wire this up with states: [finish, fail] in your borgmatic config so
# containers are never left stopped even when a backup errors:
#
#   commands:
#     - after: everything
#       states: [finish, fail]
#       run:
#           - /borgscripts/docker-start.sh

# ---- configuration -------------------------------------------------------

COMPOSE_DIR="/opt/docker/mystack"   # absolute path to the compose project directory

# --------------------------------------------------------------------------

set -euo pipefail

echo "[docker-start] Starting compose stack at '${COMPOSE_DIR}'..."
docker compose --project-directory "${COMPOSE_DIR}" start
echo "[docker-start] Done."
