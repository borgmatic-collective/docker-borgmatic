#!/bin/sh

#Variables
borgver=$(borg --version)
borgmaticver=$(borgmatic --version)
apprisever=$(apprise --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')

#Software versions
echo borgmatic $borgmaticver
echo $borgver
echo apprise $apprisever

if [ $# -eq 0 ]; then
  # Test crontab
  supercronic -test /etc/borgmatic.d/crontab.txt || exit 1

  # Start supercronic
  if [ -n "${SUPERCRONIC_EXTRA_FLAGS}" ]; then
    echo "The variable SUPERCRONIC_EXTRA_FLAGS is not empty, using extra flags"
    supercronic $SUPERCRONIC_EXTRA_FLAGS /etc/borgmatic.d/crontab.txt
  else
    echo "The variable SUPERCRONIC_EXTRA_FLAGS is empty, starting normally"
    supercronic /etc/borgmatic.d/crontab.txt
  fi
else
  if [ "$1" = "bash" ] || [ "$1" = "sh" ] || [ "$1" = "/bin/bash" ] || [ "$1" = "/bin/sh" ]; then
    exec "$@"
  else
    borgmatic "$@"
  fi
fi

