#!/bin/sh

source /etc/borgmatic.d/msmtp.env

cat >/etc/mailenv << EOF
# THIS FILE GETS RECREATED AUTOMATICALLY ON CONTAINER STARTUP
BACKUP_COMMAND="/usr/local/bin/borgmatic --stats"
MAILTO="${MAIL_TO}"
MAILSUBJECT="${MAIL_SUBJECT}"

EOF
