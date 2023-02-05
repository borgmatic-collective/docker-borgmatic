#!/bin/sh

#Variables
borgver=$(borg --version)
borgmaticver=$(borgmatic --version)
apprisever=$(apprise --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')

#Software versions
echo borgmatic $borgmaticver
echo $borgver
echo apprise $apprisever

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
