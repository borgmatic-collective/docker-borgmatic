#!/bin/sh
/bin/sh /etc/borgmatic.d/msmtprc.sh

# Import your cron file
/usr/bin/crontab /etc/borgmatic.d/crontab.txt
# Start cron
/usr/sbin/crond -f -L /dev/stdout
