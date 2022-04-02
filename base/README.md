# Borgmatic Container
<img src="https://github.com/witten/borgmatic/raw/master/docs/static/borgmatic.png" />

[![](https://images.microbadger.com/badges/image/b3vis/borgmatic.svg)](https://microbadger.com/images/b3vis/borgmatic
"Get your own image badge on microbadger.com") <img
src="https://img.shields.io/docker/pulls/b3vis/borgmatic.svg" />

### Description

A little container I wrote to automate my [Borgbackup](https://github.com/borgbackup)'s using the
excellent [Borgmatic](https://github.com/witten/borgmatic).

It uses cron to run the backups at a time you can configure in `data/borgmatic.d/crontab.txt`.

### Usage

To set your backup timing and configuration, you will need to create
[crontab.txt](data/borgmatic.d/crontab.txt) and your borgmatic
[config.yaml](data/borgmatic.d/config.yaml) and mount these files into the `/etc/borgmatic.d/`
directory. When the container starts it creates the crontab from `crontab.txt` and starts crond. By
cloning this repo in `/opt/docker/`, you will have a working setup to get started. 

If using remote repositories mount your .ssh to /root/.ssh within the container.

#### Starting and stopping containers from hooks

In case you are using the container to backup docker volumes used by other containers, you might
want to make sure that the data is consistent and doesn't change while the backup is running. The
easiest way to ensure this is to stop the affected containers before the backup and restart them
afterwards. You can use the appropriate [borgmatic
hooks](https://torsion.org/borgmatic/docs/how-to/add-preparation-and-cleanup-steps-to-backups/) and
[control the docker engine through the API](https://docs.docker.com/engine/api/) using the hosts
docker socket.

Please note that you might want to prefer the `*_everything` hooks to the `*_backup` hooks, as
`after_backup` will not run if the backup fails for any reason (missing disk space, etc.) and
therefore the containers stay stopped.

First mount the docker socket from the host by adding `-v /var/run/docker.sock:/var/run/docker.sock`
to your `run` command or in the volume list of your `docker-compose.yml`.

Then use the following example to create the start/stop hooks in the `config.yml` for the containers
that you want to control.

```yaml
hooks:
    before_everything:
        - echo "Stopping containers..."
        - 'echo -ne "POST /v1.41/containers/<container1-name>/stop HTTP/1.1\r\nHost: localhost\r\n\r\n" | nc local:/var/run/docker.sock 80 > /dev/null && echo "Stopped Container 1" || echo "Failed to stop Container 1"'
        - 'echo -ne "POST /v1.41/containers/<container2-name>/stop HTTP/1.1\r\nHost: localhost\r\n\r\n" | nc local:/var/run/docker.sock 80 > /dev/null && echo "Stopped Container 2" || echo "Failed to stop Container 2"'
        - echo "Containers stopped."
        - echo "Starting a backup."

    after_everything:
        - echo "Finished a backup."
        - echo "Restarting containers..."
        - 'echo -ne "POST /v1.41/containers/<container1-name>/start HTTP/1.1\r\nHost: localhost\r\n\r\n" | nc local:/var/run/docker.sock 80 > /dev/null && echo "Started Container 1" || echo "Failed to start Container 1"'
        - 'echo -ne "POST /v1.41/containers/<container2-name>/start HTTP/1.1\r\nHost: localhost\r\n\r\n" | nc local:/var/run/docker.sock 80 > /dev/null && echo "Started Container 2" || echo "Failed to start Container 2"'
        - echo "Containers restarted."
```

### Example run command
```
docker run \
  --detach --name borgmatic \
  -v /home:/mnt/source:ro \
  -v /opt/docker/docker-borgmatic/data/repository:/mnt/borg-repository \
  -v /opt/docker/docker-borgmatic/data/borgmatic.d:/etc/borgmatic.d/ \
  -v /opt/docker/docker-borgmatic/data/.config/borg:/root/.config/borg \
  -v /opt/docker/docker-borgmatic/data/.ssh:/root/.ssh \
  -v /opt/docker/docker-borgmatic/data/.cache/borg:/root/.cache/borg \
  -e TZ=Europe/Berlin \
  b3vis/borgmatic
```
While the parameters above are sufficient for regular backups, following additional privileges will
be needed to mount an archive as FUSE filesystem:
```
--cap-add SYS_ADMIN \
--device /dev/fuse \
--security-opt label:disable \
--security-opt apparmor:unconfined
```
Depending on your security system, `--security-opt` parameters may not be necessary. `label:disable`
is needed for *SELinux*, while `apparmor:unconfined` is needed for *AppArmor*.

To init the repo with encryption, run:
```
docker exec borgmatic \
sh -c "borgmatic --init --encryption repokey-blake2"
```

### Layout
#### /mnt/source
Your data you wish to backup. For *some* safety you may want to mount read-only. Borgmatic is
running as root so all files can be backed up. 
#### /mnt/borg-repository
Mount your borg backup repository here.
#### /etc/borgmatic.d
Where you need to create crontab.txt and your borgmatic config.yml
- To generate an example borgmatic configuration, run:
```
docker exec borgmatic \
sh -c "cd && generate-borgmatic-config -d /etc/borgmatic.d/config.yaml"
```
- crontab.txt example: In this file set the time you wish for your backups to take place default is
  1am every day. In here you can add any other tasks you want ran
```
0 1 * * * PATH=$PATH:/usr/bin /usr/bin/borgmatic --stats -v 0 2>&1
```
#### /root/.borgmatic
**Note** this is now redundant and has been deprecated, please remove this from your configs
#### /root/.config/borg
Here the borg config and keys for keyfile encryption modes are stored. Make sure to backup your
keyfiles! Also needed when encryption is set to none.
#### /root/.ssh
Mount either your own .ssh here or create a new one with ssh keys in for your remote repo locations.
#### /root/.cache/borg
A non-volatile place to store the borg chunk cache.

### Environment
- Time zone, e.g. `TZ="Europe/Berlin"'`.
- SSH parameters, e.g. `BORG_RSH="ssh -i /root/.ssh/id_ed25519 -p 50221"`
- BORG_RSH="ssh -i /root/.ssh/id_ed25519 -p 50221"
- Repository passphrase, e.g. `BORG_PASSPHRASE="DonNotMissToChangeYourPassphrase"`

### Docker Compose
  - Prepare your configuration
    1. `cp .env.template .env`
    2. Set your environment and adapt volumes as needed
  - To start the container for backup: `docker-compose up -d`
  - For backup restore: 
    1. Stop the backup container: `docker-compose down`
    2. Run an interactive shell: `docker-compose -f docker-compose.yml -f docker-compose.restore.yml
       run borgmatic`
    3. Fuse-mount the backup: `borg mount /mnt/borg-repository <mount_point>`
    4. Restore your files
    5. Finally unmount and exit: `borg umount <mount_point> && exit`.
  - In case Borg fails to create/acquire a lock: `borg break-lock /mnt/repository`
