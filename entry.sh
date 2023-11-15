#!/bin/sh
# timezone
/bin/echo $TZ > /etc/timezone
# setup msmtp
#!/bin/sh
cat >/etc/msmtprc << EOF
# Set default values for all following accounts.
defaults
# auth             on
# tls              on
# tls_starttls	 on
tls_trust_file   /etc/ssl/certs/ca-certificates.crt
logfile		     /dev/stdout
account	default
host ${MAIL_RELAY_HOST}
port ${MAIL_PORT}
from ${MAIL_FROM}
user ${MAIL_USER}
password ${MAIL_PASSWORD}
EOF
# run borgmatic
/usr/local/bin/borgmatic --log-file /dev/stdout --log-file-verbosity 2 2>&1