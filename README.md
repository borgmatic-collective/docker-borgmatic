# Borgmatic Container

![](https://github.com/witten/borgmatic/raw/master/docs/static/borgmatic.png)

[![](https://img.shields.io/github/issues/borgmatic-collective/docker-borgmatic)](https://github.com/borgmatic-collective/docker-borgmatic/issues)
[![](https://img.shields.io/github/stars/borgmatic-collective/docker-borgmatic)](https://github.com/borgmatic-collective/docker-borgmatic/stargazers)
[![](https://img.shields.io/docker/stars/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)
[![](https://img.shields.io/docker/pulls/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)

### Description

A little container I wrote to automate my [Borgbackup](https://github.com/borgbackup)'s using the excellent [Borgmatic](https://github.com/witten/borgmatic).

This image comes in the three flavours:
1. [base](./base/) (vanilla), with docker log
2. [msmtp](./msmtp/), with e-mail notifications
3. [ntfy](./ntfy/), with push notifications

> **Warning**
> As of 2022-01-29 this image has switched to use [Supercronic](https://github.com/aptible/supercronic) instead of cron from alpine

### Usage
General instructions can be found in the base image [README](./base/).

### Additional Reading
[Backup Docker using Borgmatic](https://www.modem7.com/books/docker-backup/page/backup-docker-using-borgmatic) - Thank you [@modem7](https://github.com/modem7)
