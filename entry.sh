#!/bin/sh
# Import your cron file
/usr/bin/crontab /config/crontab.txt
# Start cron
/usr/sbin/crond -f -L /config/crond.log
