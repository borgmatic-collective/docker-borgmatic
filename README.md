# Borgmatic Container
<img src="https://camo.githubusercontent.com/24287203ea7c7906b72341780f067ad44408ff99/68747470733a2f2f63646e2e7261776769742e636f6d2f77697474656e2f626f72676d617469632f6d61737465722f7374617469632f626f72676d617469632e737667" width="200" height="200" />

### Description

A little container I wrote to automate my [Borgbackup](https://github.com/borgbackup)'s using the excellent [Borgmatic](https://github.com/witten/borgmatic).

It uses cron to run the backups at a time you can configure in `crontab.txt`.

### Usage

You will need to create crontab.txt and your borgmatic config.yml and mount these files into your /config directory. When the container starts it creates the crontab from /config/crontab.txt and starts crond.

If using remote repositories mount your .ssh to /root/.ssh within the container

### Example run command
```
docker run \
  --detach --name borgmatic \
  -v /home:/source/home:ro \
  -v /mnt/borg:/repository \
  -v /home/user/.ssh:/root/.ssh \
  -v /srv/borgmatic/config:/config \
  -v /srv/borgmatic/borgmatic.d:/etc/borgmatic.d/
  -v /srv/borgmatic/cache:/cache \
  b3vis/borgmatic
```
While the parameters above are sufficient for regular backups, following additional privileges will be needed to mount an archive as FUSE filesystem:
```
--cap-add SYS_ADMIN \
--device /dev/fuse \
--security-opt label:disable \
--security-opt apparmor:unconfined
```
Depending on your security system, `--security-opt` parameters may not be neccessary. `label:disable` is needed for *SELinux*, while `apparmor:unconfined` is needed for *AppArmor*.

### Layout

#### /config
Where you need to create crontab.txt and your borgmatic config.yml

#### crontab.txt example
In this file set the time you wish for your backups to take place default is 1am every day. In here you can add any other tasks you want ran
```
0 1 * * * PATH=$PATH:/usr/bin /usr/bin/borgmatic -c /config  --stats -v 0 2>&1
```
#### /cache
A non volatile place to store the borg chunk cache
#### /source
Your data you wish to backup
#### /repository
Mount your borg backup repository here
#### /root/.ssh
Mount either your own .ssh here or create a new one with ssh keys in for your remote repo locations
#### /etc/borgmatic.d
Mount your borgmatic configuration file(s) here. To generate an example configuration, run:
```
docker exec borgmatic \
sh -c "generate-borgmatic-config -d /etc/borgmatic.d/config.yaml"
```
### Environment

#### TZ
You can set TZ to specify a time zone, `Europe/Berlin`.
