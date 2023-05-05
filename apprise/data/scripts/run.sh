#!/bin/bash

LOGFILE="/tmp/backup_run_$(date +%s).log"

set -o pipefail
/usr/local/bin/borgmatic --stats -v 0 2>&1 | tee $LOGFILE

if [ $? -eq "0" ]; then
    SUBJECT_PREFIX="SUCCESS"
else
    SUBJECT_PREFIX="FAILED"
fi

/scripts/send_notification.py "$SUBJECT_PREFIX: Borgmatic" "$(cat $LOGFILE)"

rm $LOGFILE