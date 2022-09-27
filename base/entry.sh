#!/bin/bash

# Version variables
borgver=$(borg --version)
borgmaticver=$(borgmatic --version)
apprisever=$(apprise --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')

# Software versions
echo borgmatic $borgmaticver
echo $borgver
echo apprise $apprisever

# Disable cron if it's set to disabled.
if [[ "$CRON" =~ ^(false|disabled|off)$ ]]; then
    echo "Disabling cron, removing configuration"
    # crontab -r # quite destructive
    # echo -n > /etc/crontabs/root # Empty config, doesn't look as nice with "crontab -l"
    echo "# Cron disabled" > /etc/crontabs/root
    echo "Cron is now disabled"
# Apply default or custom cron if $CRON is unset or set (not null):
elif [[ -v CRON ]]; then
    CRON="${CRON:-"0 1 * * *"}"
    CRON_COMMAND="${CRON_COMMAND:-"borgmatic --stats -v 0 2>&1"}"
    echo "$CRON $CRON_COMMAND" > /etc/crontabs/root
    echo "Applying custom cron"
# If nothing is set, revert to default behaviour
else
    echo "Applying crontab.txt"
    crontab /etc/borgmatic.d/crontab.txt
fi

# Apply extra cron if it's set
if [ -v EXTRA_CRON ]
then
    echo "$EXTRA_CRON" >> /etc/crontabs/root
fi

# Current crontab var
crontab=$(crontab -l)

# Output cron settings to console
printf "Cron job set as: \n$crontab\n"

# Start Cron
crond -f -L /dev/stdout