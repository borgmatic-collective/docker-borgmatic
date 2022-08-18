#!/bin/sh

# Generate Cron variables
export CRON=${CRON:-"0 1 * * *"}
export CRON_COMMAND=${CRON_COMMAND:-"borgmatic --stats -v 0 2>&1"}

# Output cron settings to console
echo "Cron job set as: \"$CRON $CRON_COMMAND\""

# Version variables
borgver=$(borg --version)
borgmaticver=$(borgmatic --version)
apprisever=$(apprise --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')

# Software versions
echo borgmatic $borgmaticver
echo $borgver
echo apprise $apprisever

# Start cron
echo "$CRON $CRON_COMMAND" > /etc/crontabs/root
/usr/sbin/crond -f -L /dev/stdout
