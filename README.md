# Borgmatic Container
<img src="https://camo.githubusercontent.com/24287203ea7c7906b72341780f067ad44408ff99/68747470733a2f2f63646e2e7261776769742e636f6d2f77697474656e2f626f72676d617469632f6d61737465722f7374617469632f626f72676d617469632e737667" width="200" height="200" />

### Description

A little container I wrote to automate my [Borgbackup](https://github.com/borgbackup)'s using the excellent [Borgmatic](https://github.com/witten/borgmatic).

It uses cron to run the backups at a time you can configure in `data/borgmatic.d/crontab.txt`.

### Usage

To set your backup timing and configuration, you will need to create [crontab.txt](data/borgmatic.d/crontab.txt) and your borgmatic [config.yaml](data/borgmatic.d/config.yaml) and mount these files into the `/etc/borgmatic.d/` directory. When the container starts it creates the crontab from `crontab.txt` and starts crond. By cloning this repo in `/opt/docker/`, you will have a working setup to get started. 

If using remote repositories mount your .ssh to /root/.ssh within the container

### Example run command
```
docker run \
  --detach --name borgmatic \
  -v /home:/mnt/source:ro \
  -v /opt/docker/docker-borgmatic/data/repository:/mnt/repository \
  -v /opt/docker/docker-borgmatic/data/borgmatic.d:/etc/borgmatic.d/ \
  -v /opt/docker/docker-borgmatic/data/.config/borg:/root/.config/borg \
  -v /opt/docker/docker-borgmatic/data/.ssh:/root/.ssh \
  -v /opt/docker/docker-borgmatic/data/.cache/borg:/root/.cache/borg \
  -e TZ=Europe/Berlin \
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

To init the repo with encryption, run:
```
docker exec borgmatic \
sh -c "borgmatic --init --encryption repokey-blake2"
```

### Layout
#### /mnt/source
Your data you wish to backup. For *some* safety you may want to mount read-only. Borgmatic is running as root so all files can be backed up. 
#### /mnt/repository 
Mount your borg backup repository here.
#### /etc/borgmatic.d
Where you need to create crontab.txt and your borgmatic config.yml
- To generate an example borgmatic configuration, run:
```
docker exec borgmatic \
sh -c "generate-borgmatic-config -d /etc/borgmatic.d/config.yaml"
```
- crontab.txt example: In this file set the time you wish for your backups to take place default is 1am every day. In here you can add any other tasks you want ran
```
0 1 * * * PATH=$PATH:/usr/bin /usr/bin/borgmatic --stats -v 0 2>&1
```
#### /root/.config/borg
Here the borg config and keys for keyfile encryption modes are stored. Make sure to backup your keyfiles!
#### /root/.ssh
Mount either your own .ssh here or create a new one with ssh keys in for your remote repo locations.
#### /root/.cache/borg
A non volatile place to store the borg chunk cache.
### Environment
- Time zone, e.g. `TZ="Europe/Berlin"'`.
- SSH parameters, e.g. `BORG_RSH="ssh -i /root/.ssh/id_ed25519 -p 50221"`
- BORG_RSH="ssh -i /root/.ssh/id_ed25519 -p 50221"
- Repository passphrase, e.g. `BORG_PASSPHRASE="DonNotMissToChangeYourPassphrase"`

### Docker Compose
  - To start the container for backup:
    1. Set BORG_PASSPHRASE and backup source/target in .env
    2. Run `docker-compose up -d`
  - For backup restore: 
    1. Stop the backup container: `docker-compose down`
    2. Run an interactive shell: `docker-compose -f docker-compose.yml -f docker-compose.restore.yml run borgmatic`
    3. Fuse-mount the backup: `borg mount /mnt/repository <mount_point>`
    4. Restore your files
    5. Finally unmount and exit: `borg umount <mount_point> && exit`.
  - In case Borg fails to create/acquire a lock: `borg break-lock /mnt/repository`
