#!/bin/sh

# Path
CRONTAB_PATH="/etc/borgmatic.d/crontab.txt"

#Variables
borgver=$(borg --version)
borgmaticver=$(borgmatic --version)
apprisever=$(apprise --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')

#Software versions
echo borgmatic $borgmaticver
echo $borgver
echo apprise $apprisever

if [ $# -eq 0 ]; then

  # Allow setting of custom crontab, so check if crontab file exists
  if [ -f "$CRONTAB_PATH" ]; then
    echo "Crontab file exists, using it"
  else
    if [ -z "${BACKUP_CRON}" ]; then
      echo "Environment variable BACKUP_CRON is not set, using default value: 0 1 * * *"
      export BACKUP_CRON="0 1 * * *"
    else
      echo "Environment variable BACKUP_CRON is set, using value $BACKUP_CRON"
    fi
    echo "$BACKUP_CRON PATH=\$PATH:/usr/local/bin /usr/local/bin/borgmatic --stats -v 0 2>&1" > $CRONTAB_PATH
  fi

  if [ "${RUN_ON_STARTUP:-}" == "true" ]; then
    echo "Running on startup..."
    /usr/local/bin/borgmatic --stats -v 0 2>&1
  fi

  # Test crontab
  supercronic -test /etc/borgmatic.d/crontab.txt || exit 1

  # Start supercronic
  if [ -n "${SUPERCRONIC_EXTRA_FLAGS}" ]; then
    echo "The variable SUPERCRONIC_EXTRA_FLAGS is not empty, using extra flags"
    exec supercronic $SUPERCRONIC_EXTRA_FLAGS /etc/borgmatic.d/crontab.txt
  else
    echo "The variable SUPERCRONIC_EXTRA_FLAGS is empty, starting normally"
    exec supercronic /etc/borgmatic.d/crontab.txt
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
