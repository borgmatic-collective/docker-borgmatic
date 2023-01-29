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
supercronic /etc/borgmatic.d/crontab.txt
