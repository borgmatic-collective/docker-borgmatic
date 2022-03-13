#!/bin/sh

cat >/etc/mailenv << EOF
BACKUP_COMMAND="/usr/bin/borgmatic --stats -v 0"
MAILTO="${MAIL_TO}"
MAILSUBJECT="${MAIL_SUBJECT}"

EOF