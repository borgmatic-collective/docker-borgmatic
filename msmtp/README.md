# mail notification for Borgmatic Container 

### Description

This image adds mail notification with [msmtp](https://marlam.de/msmtp/) to the docker-bormatic.

### Usage

For general usage instuctions see the [README](../base/README.md) of the base image.

If you want to mail the results from cron:
* Add your mail relay details to the [msmtp.env](msmtp.env.template) or mount your own [msmtprc](https://wiki.alpinelinux.org/wiki/Relay_email_to_gmail_(msmtp,_mailx,_sendmail) to `/etc/msmtprc`
* Add add your mail address to crontag.txt and uncomment the line, e.g. `MAILTO=log@example.com`
* Please note that logs will no longer end up in Docker logs when MAILTO is set.

### Environment
Set your mail configuration in `msmtp.env`
- Your mail relay host `MAIL_RELAY_HOST=mail.example.com`
- Port of your mail relay `MAIL_PORT=587`
- Username used to log in into your relay service `MAIL_USER=borgmatic_log@example.com`
- Password for relay login   `MAIL_PASSWORD=SuperS3cretMailPw`
- From part in your log mail `MAIL_FROM=borgmatic`
