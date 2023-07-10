#!/bin/sh

# Path
CRONTAB_PATH="/etc/borgmatic.d/crontab.txt"

# Variables
borgver=$(borg --version)
borgmaticver=$(borgmatic --version)
apprisever=$(apprise --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')

# Software versions
echo borgmatic "$borgmaticver"
echo "$borgver"
echo apprise "$apprisever"

# Load any Docker secrets starting with BORG if they exist
for secret_file in /run/secrets/BORG*; do
  secret_name=$(basename "$secret_file")
  secret_value=$(cat "$secret_file")
  export "${secret_name}=${secret_value}"
  echo "Loaded secret ${secret_name}"
done

if [ $# -eq 0 ]; then
  # Allow setting of custom crontab, so check if crontab file exists
  if [ -f "$CRONTAB_PATH" ]; then
    echo "Crontab file exists, using it"
  else
    if [ -z "${BACKUP_CRON}" ]; then
      echo "Environment variable BACKUP_CRON is not set, using default value: 0 1 * * *"
      export BACKUP_CRON="0 0 * * *"
    else
      echo "Environment variable BACKUP_CRON is set, using value $BACKUP_CRON"
    fi
    echo "$BACKUP_CRON PATH=\$PATH:/usr/local/bin /usr/local/bin/borgmatic --stats -v 0 2>&1" >"$CRONTAB_PATH"
  fi

  if [ "${RUN_ON_STARTUP:-}" = "true" ]; then
    echo "Running on startup..."
    /usr/local/bin/borgmatic --stats -v 0 2>&1
  fi

  # Test crontab
  supercronic -test "$CRONTAB_PATH" || exit 1

  # Start supercronic
  if [ -n "${SUPERCRONIC_EXTRA_FLAGS}" ]; then
    echo "The variable SUPERCRONIC_EXTRA_FLAGS is not empty, using extra flags"
    exec supercronic "$SUPERCRONIC_EXTRA_FLAGS" "$CRONTAB_PATH"
  else
    echo "The variable SUPERCRONIC_EXTRA_FLAGS is empty, starting normally"
    exec supercronic "$CRONTAB_PATH"
  fi
else
  if [ "$1" = "bash" ] || [ "$1" = "sh" ] || [ "$1" = "/bin/bash" ] || [ "$1" = "/bin/sh" ]; then
    # Run Shell
    exec "$@"
  else
    # Run borgmatic with subcommand
    exec borgmatic "$@"
  fi
fi
