# Borgmatic Container

![](https://github.com/witten/borgmatic/raw/main/docs/static/borgmatic.png)

[![](https://img.shields.io/github/issues/borgmatic-collective/docker-borgmatic)](https://github.com/borgmatic-collective/docker-borgmatic/issues)
[![](https://img.shields.io/github/stars/borgmatic-collective/docker-borgmatic)](https://github.com/borgmatic-collective/docker-borgmatic/stargazers)
[![](https://img.shields.io/docker/stars/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)
[![](https://img.shields.io/docker/pulls/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)

### Description


This repository provides a Docker image for [Borgmatic](https://github.com/witten/borgmatic), a simple and efficient backup tool based on [Borgbackup](https://github.com/borgbackup). The image is designed to make it easy to set up and run Borgmatic (with Borg and optionally Cron daemon) within a Docker container, enabling you to streamline your backup process and ensure the safety of your data.

> **Warning**
> As of 2022-01-29 this image has switched to use [Supercronic](https://github.com/aptible/supercronic) instead of cron from alpine

> **Warning**
> As of 2023-06-23 msmtp and ntfy flavors have been discontinued. This image has now switched to apprise.

### Usage
---

### Prerequisites
Before proceeding, ensure that you have Docker installed and properly configured on your system. Refer to the Docker documentation for installation instructions specific to your operating system.

### As binary
This image can be used to run borgmatic as binary by passing the borgmatic command while running the container. It allows you to isolate your system and execute Borgmatic commands without directly installing Borgmatic on your host system and only keeping persistent data.

To execute borgmatic commands, you can run your container by passing borgmatic subcommands:
```
docker run --rm -it \
MOUNT_FLAGS_HERE \
ghcr.io/borgmatic-collective/borgmatic \
list
```

This will execute `borgmatic list` in your container. The idea is to create symlink to a script which executes this. Now create a new file `borgmatic-docker.sh` somewhere like your workspace or home directory.
```
#!/bin/sh

docker run --rm -it \
MOUNT_FLAGS_HERE \
ghcr.io/borgmatic-collective/borgmatic \
"$@"
```
Modify the above script as per your needs and copy it's path. Now you can either create a symbolic link to this script or add it as alias.

1. Create a symlink to a directory that exists in your PATH variable e.g.:
```
chmod +x /path/to/script/borgmatic-docker.sh
sudo ln [-s] /path/to/script/borgmatic-docker.sh /usr/local/bin/borgmatic
```

2. Or, to create an alias add this to your `~/.bashrc` or similar file for other shells.
```
alias borgmatic="sh /path/to/script/borgmatic-docker.sh"
```

**Tip** You can view list of available command line options in [Borgmatic's docs](https://torsion.org/borgmatic/docs/reference/command-line/)

### Running as daemon
To keep the container always running for continous backup, you can run it in detached mode. If you do not pass the command, by default it'll start the cron daemon which will run borgmatic at interval set in crontab.txt file.

```
docker run -d --restart=always \
MOUNT_FLAGS_HERE \
ghcr.io/borgmatic-collective/borgmatic \
```

If you ever need to run borgmatic manually, for instance to view or recover files, run:

```
docker exec -it container_id_or_name bash
```

Then you can run `borgmatic` directly within that shell.

### Structure deployment with docker-compose
<!-- Configure .env -->
1. Copy `.env.template` to `.env` and edit it to your needs.
```
cp .env.template .env
```

You will need to configure environment variables for volumes. You can also directly configure `docker-compose.yml` file.

Beside these, you can also set other configuration variables in your `.env` file. See [Environment](#environment) section for more details.

2. Start the container
```
docker-compose up -d
```

3. To view logs
```
docker-compose logs -f
```

#### Miscelaneous

If you want to run borgmatic commands using this configuration instead of starting the container as daemon, you can run:
<!-- TODO: entry.sh is not working with docker-compose, having to pass full command -->
```
docker-compose run --rm borgmatic borgmatic list
```

If a container is already running, you can execute borgmatic commands in it by running:
```
docker-compose exec borgmatic ls
# or to run a shell
docker-compose exec borgmatic bash
```

#### Restoring backups

1. Stop the backup container: `docker-compose down`
2. Modify volume `/host/mount/location` in `docker-compose.restore.yml` file to point to the location where you want to restore your backup.
3. Run an interactive shell: `docker-compose -f docker-compose.yml -f docker-compose.restore.yml run borgmatic`
4. Fuse-mount the backup: `borg mount /mnt/borg-repository <mount_point>`
5. Restore your files
6. Finally unmount and exit: `borg umount <mount_point> && exit`.

**Tip** In case Borg fails to create/acquire a lock: `borg break-lock /mnt/repository`


### Volumes
---

The following volumes are available for mounting:
| Volume | Description |
| --- | --- |
| `/mnt/source` | Your data you wish to backup. For *some* safety you may want to mount read-only. Borgmatic is running as root so all files can be backed up. |
| `/mnt/borg-repository` | Mount your borg backup repository here. |
| `/etc/borgmatic.d` | Where you need to create crontab.txt and your borgmatic config.yml |
| `/root/.borgmatic` | **Note** this is now redundant and has been deprecated, please remove this from your configs |
| `/root/.config/borg` | Here the borg config and keys for keyfile encryption modes are stored. Make sure to backup your keyfiles! Also needed when encryption is set to none. |
| `/root/.ssh` | Mount either your own .ssh here or create a new one with ssh keys in for your remote repo locations. |
| `/root/.cache/borg` | A non-volatile place to store the borg chunk cache. |

To generate an example borgmatic configuration, run:
```
docker exec borgmatic \
bash -c "cd && generate-borgmatic-config -d /etc/borgmatic.d/config.yaml"
```
crontab.txt example: In this file set the time you wish for your backups to take place default is 1am every day. In here you can add any other tasks you want ran
```
0 1 * * * PATH=$PATH:/usr/bin /usr/bin/borgmatic --stats -v 0 2>&1
```

### Environment
---

You can set the following environment variables:
| Variable | Description |
| --- | --- |
| `TZ` | Time zone, e.g. `TZ="Europe/Berlin"'`. |
| `BORG_RSH` | SSH parameters, e.g. `BORG_RSH="ssh -i /root/.ssh/id_ed25519 -p 50221"` |
| `BORG_PASSPHRASE` | Repository passphrase, e.g. `BORG_PASSPHRASE="DonNotMissToChangeYourPassphrase"` |
| `BACKUP_CRON` | Cron schedule to run borgmatic. Default:`0 1 * * *` |
| `RUN_ON_STARTUP` | Run borgmatic on startup. e.g.: `RUN_ON_STARTUP=true` |

Beside that, you can also pass any environment variable that is supported by borgmatic. See documentation for [Borgmatic](https://torsion.org/borgmatic/) and [Borg](https://borgbackup.readthedocs.io/) and for a list of supported variables. 

### Advanced
---

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
  ghcr.io/borgmatic-collective/borgmatic
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
bash -c "borgmatic --init --encryption repokey-blake2"
```

### Additional Reading
[Backup Docker using Borgmatic](https://www.modem7.com/books/docker-backup/page/backup-docker-using-borgmatic) - Thank you [@modem7](https://github.com/modem7)
