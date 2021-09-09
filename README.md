# Borgmatic Container

![](https://github.com/witten/borgmatic/raw/master/docs/static/borgmatic.png)

[![](https://img.shields.io/github/issues/b3vis/docker-borgmatic)](https://github.com/b3vis/docker-borgmatic/issues)
[![](https://img.shields.io/github/stars/b3vis/docker-borgmatic)](https://github.com/b3vis/docker-borgmatic/stargazers)
[![](https://img.shields.io/docker/stars/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)
[![](https://img.shields.io/docker/cloud/build/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)
[![](https://img.shields.io/docker/pulls/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)

### Description

A little container I wrote to automate my [Borgbackup](https://github.com/borgbackup)'s using the excellent [Borgmatic](https://github.com/witten/borgmatic).

This image comes in the three flavours:
1. [base](./base/README.md) (vanilla), with docker log
2. [msmtp](./msmtp/README.md), with e-mail notifications
3. [ntfy](./ntfy/README.md), with push notifications

### Usage
General instructions can be found in the base image [README](./base/README.md).

### Additional Reading
[Backup Docker using Borgmatic](https://www.modem7.com/books/docker-backup/page/backup-docker-using-borgmatic) - Thank you @modem7