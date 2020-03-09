# ntfy notification for Borgmatic Container

### Description

This image adds mail notification with [ntfy](https://github.com/dschep/ntfy) to the docker-bormatic.

### Usage

For general usage instuctions see the [README](../base/README.md) of the base image.


### Layout
#### /root/.config/ntfy
Where you can map your own `ntfy.yml` config to have Borgmatic send notifications


### ntfy
Mount your own `ntfy.yml` to `/root/.config/ntfy/ntfy.yml` to set your backends for ntfy. Alternatively you can interactively send notifications via a command with API keys in line. I've opted to just map my own `ntfy.yml`

#### Example for your borgmatic config.yml
```
hooks:
    before_backup:
        - ntfy -b pushover -t Borgmatic send "Borgmatic: Backup Starting"
    after_backup:
        - ntfy -b pushover -t Borgmatic send "Borgmatic: Backup Finished"
    on_error:
        - ntfy -b pushover -t Borgmatic send "Borgmatic: Backup Error!"
```
