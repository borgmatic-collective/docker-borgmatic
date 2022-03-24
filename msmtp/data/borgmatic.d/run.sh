#!/bin/sh

source /etc/mailenv
LOGFILE="/tmp/backup_run_$(date +%s).log"

set -o pipefail
$BACKUP_COMMAND 2>&1 | tee $LOGFILE

if [ $? -eq "0" ]; then
    SUBJECT_PREFIX="=?utf-8?Q? =E2=9C=85 SUCCESS?="
else
    SUBJECT_PREFIX="=?utf-8?Q? =E2=9D=8C FAILED?="
fi

if [ -n "$MAILTO" ]; then
    echo -e "Subject: $SUBJECT_PREFIX: $MAILSUBJECT\n\n$(cat $LOGFILE)\n" |
        sendmail -t $MAILTO
fi

rm $LOGFILE