#!/bin/sh
/bin/sh /scripts/msmtprc.sh
/bin/sh /scripts/env.sh

# Import your cron file
/usr/bin/crontab /etc/borgmatic.d/crontab.txt
# Start cron
/usr/sbin/crond -f -L /dev/stdout
