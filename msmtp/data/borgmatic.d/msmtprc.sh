#!/bin/sh

cat >/etc/msmtprc << EOF
# THIS FILE GETS RECREATED AUTOMATICALLY ON CONTAINER STARTUP
# Set default values for all following accounts.
defaults
auth             on
tls              on
tls_starttls	 on
tls_trust_file   /etc/ssl/certs/ca-certificates.crt
logfile		     /var/log/sendmail.log

account	default
host ${MAIL_RELAY_HOST}
port ${MAIL_PORT}
from ${MAIL_FROM}
user ${MAIL_USER}
password ${MAIL_PASSWORD}

EOF