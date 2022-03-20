# E-Mail notifications for docker-borgmatic 

### Description

This image adds e-mail notifications with [msmtp](https://marlam.de/msmtp/) to
the docker-borgmatic container.

### Usage

For general usage instructions see the [README](../base/README.md) of the base
image.

To setup e-mail notifications follow these steps:

* Add your mail relay details to the [msmtp.env](msmtp.env.template). See
  the list of environment variables below.
* Restart the container to apply the changes.

For those who update the image from `v1.1.17-1.5.23` or below, you might want to
migrate to the new e-mail notification script that provides you proper subject
lines and adds further possibilities to use the environment for configuration:

* Remove the `MAILTO` from your `crontab.txt`.
* Edit your `crontab.txt` to match the [upstream file](data/borgmatic.d/crontab.txt).
* Add the [`env.sh`](data/borgmatic.d/env.sh) and
  `run.sh`(data/borgmatic.d/run.sh).
* Extend the environment in `msmtp.env` to contain `MAIL_TO` and `MAIL_SUBJECT`.

### Environment

Set your mail configuration in `msmtp.env`:

| Key                | Description                |
| ------------------ | -------------------------- |
| `MAIL_RELAY_HOST`  | IP or hostname of the mail relay (SMTP server) |
| `MAIL_PORT`        | SMTP port of the mail relay |
| `MAIL_USER`        | Username for SMTP login |
| `MAIL_PASSWORD`    | Password for SMTP login |
| `MAIL_FROM`        | From address for e-mail notifications |
| `MAIL_TO`          | Recipients for e-mail notifications |
| `MAIL_SUBJECT`     | Subject line for e-mail notifications |