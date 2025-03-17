# borgmatic Container

![](https://github.com/witten/borgmatic/raw/main/docs/static/borgmatic.png)

[![](https://img.shields.io/github/issues/borgmatic-collective/docker-borgmatic)](https://github.com/borgmatic-collective/docker-borgmatic/issues)
[![](https://img.shields.io/github/stars/borgmatic-collective/docker-borgmatic)](https://github.com/borgmatic-collective/docker-borgmatic/stargazers)
[![](https://img.shields.io/docker/stars/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)
[![](https://img.shields.io/docker/pulls/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)

## Description ##


This repository provides a Docker image for [borgmatic](https://github.com/witten/borgmatic), a simple and efficient backup tool based on [Borgbackup](https://github.com/borgbackup). The image is designed to make it easy to set up and run borgmatic (with Borg and optionally Cron daemon) within a Docker container, enabling you to streamline your backup process and ensure the safety of your data.

> **Warning**
> As of 2023-06-23 msmtp and ntfy flavors have been discontinued. This image has now switched to apprise.

> **Warning**
> Secrets will be implemented differently from October 2024. From `*_FILE` to `FILE__*`

## Usage ##

### Prerequisites
Before proceeding, ensure that you have [Docker](https://www.docker.com/) installed and properly configured on your system. Refer to the [Docker documentation](https://docs.docker.com/engine/install/) for installation instructions specific to your operating system. If you want to use [docker-compose](https://docs.docker.com/compose/install/), you may also need to install it seperately.
Alternatively, you can also use [podman](https://podman.io/docs) to run this image.

### Getting Started

Run this command to create data directories required by this image under your prefered directory.

```
mkdir data/{borgmatic.d,repository,.config,.ssh,.cache}
```
Configure a copy of borgmatic's [config.yaml](data/borgmatic.d/config.yaml) in `data/borgmatic.d` and run the container. You can modify any of the host mount point to fit your backup configuration.

```
docker run \
  --detach --name borgmatic \
  -v /home:/mnt/source:ro \
  -v ./data/repository:/mnt/borg-repository \
  -v ./data/borgmatic.d:/etc/borgmatic.d/ \
  -v ./data/.config/borg:/root/.config/borg \
  -v ./data/.ssh:/root/.ssh \
  -v ./data/.cache/borg:/root/.cache/borg \
  -v ./data/.state/borgmatic:/root/.local/state/borgmatic \
  -e TZ=Europe/Berlin \
  ghcr.io/borgmatic-collective/borgmatic
```

See [Other usage methods](#other-usage-methods) below for more options.

### Running the container the first time ###

When you run the container for the first time, you'll need to execute into the container and run a command to initialize the repository in the directory you've specified in your docker configuration:

```
docker exec -it borgmatic /bin/sh
borgmatic init --encryption repokey
```

In addition, it may be a good idea to manually perform a backup to ensure everything performs as expected:

```
docker exec -it borgmatic /bin/sh
borgmatic --stats -v 1 --files
```

Both these commands will use the `borgmatic.d/config.yaml` file you provided, along with the `BORG_PASSPHRASE` and other environment variables in your docker configuration.

> **Note/Gotcha for archive names:** 
> By default borgmatic uses `{hostname}` for naming (and then pruning, compacting archives). However the docker containers hostname changes every time it's rebuilt. To ensure consistent naming across archives and a properly working prune/compact you should specifically set the archive name in the config.yaml e.g. `archive_name_format: 'my-pc-backup-{now:%Y-%m-%d-%H%M%S}`.

## Volumes ##

The following volumes are available for mounting:
| Volume | Description |
| --- | --- |
| `/mnt/source` | Your data you wish to backup. For *some* safety you may want to mount read-only. borgmatic is running as root so all files can be backed up. |
| `/mnt/borg-repository` | Mount your borg backup repository here. |
| `/etc/borgmatic.d` | Where you need to create crontab.txt and your borgmatic config.yml |
| `/root/.borgmatic` | **Note** this is now redundant and has been deprecated, please remove this from your configs |
| `/root/.local/state/borgmatic` | Here are the state files for periodic checks. |
| `/root/.config/borg` | Here the borg config and keys for keyfile encryption modes are stored. Make sure to backup your keyfiles! Also needed when encryption is set to none. |
| `/root/.ssh` | Mount either your own .ssh here or create a new one with ssh keys in for your remote repo locations. |
| `/root/.cache/borg` | A non-volatile place to store the borg chunk cache. |

To generate an example borgmatic configuration, run:
```
docker exec borgmatic \
bash -c "cd && borgmatic config generate -d /etc/borgmatic.d/config.yaml"
```

## Environment ##

You can set the following environment variables:
| Variable | Description |
| --- | --- |
| `TZ` | Time zone, e.g. `TZ="Europe/Berlin"'`. |
| `BORG_RSH` | SSH parameters, e.g. `BORG_RSH="ssh -i /root/.ssh/id_ed25519 -p 50221"` |
| `BORG_PASSPHRASE` | Repository passphrase, e.g. `BORG_PASSPHRASE=DonNotMissToChangeYourPassphrase` |
| `BACKUP_CRON` | Cron schedule to run borgmatic. Default:`0 1 * * *` |
| `RUN_ON_STARTUP` | Run borgmatic on startup. e.g.: `RUN_ON_STARTUP=true` |
| `DOCKERCLI` | Install docker client executable to manipulate (start/stop) containers before, or after backup. See [here](#starting-and-stopping-containers-from-hooks) for a detailed explanation. |

You can also provide your own crontab file. If `data/borgmatic.d/crontab.txt` exists, `BACKUP_CRON` will be ignored in preference to it. In here you can add any other tasks you want ran
```
0 1 * * * PATH=$PATH:/usr/local/bin /usr/local/bin/borgmatic --stats -v 0 2>&1
```

Beside that, you can also pass any environment variable that is supported by borgmatic. See documentation for [borgmatic](https://torsion.org/borgmatic/) and [Borg](https://borgbackup.readthedocs.io/) and for a list of supported variables.

### Environment variables from files (Docker secrets)¶
You can set any environment variable from a file by using a special prepend `FILE__`.
As an example:
```
-e FILE__BORG_PASSPHRASE=/run/secrets/mysecretvariable
```
Will set the environment variable `BORG_PASSPHRASE` based on the contents of the `/run/secrets/mysecretvariable` file.

It is important to know that this environment variable is **not** simply available via `docker (compose) exec borgmatic sh` but only for the automatic call via the defined cron.

#### Manual commands with secrets
If you want to initialize a repository manually or start a backup outside of the cron job, proceed as follows:

- **Initialize repository**
  ```
  docker exec borgmatic /bin/sh -c 'export BORG_PASSPHRASE=$(cat /run/s6/container_environment/BORG_PASSPHRASE) && borgmatic init --encryption repokey'
  ```
- **Trigger manual backup**
  ```
  docker exec borgmatic /bin/sh -c 'export BORG_PASSPHRASE=$(cat /run/s6/container_environment/BORG_PASSPHRASE) && borgmatic create --stats -v 0'
  ```

### Docker Image Tags

The following Docker image tags are available (assuming 1.8.13 is the latest release):

- `1.8.13` - Specific version 1.8.13
- `1.8.12` - Specific version 1.8.12
- `1.8` - Latest 1.8.x version (currently 1.8.13)
- `1` - Latest 1.x.x version (currently 1.8.13)
- `latest` - Latest version (currently 1.8.13)

This tagging system allows you to pin to your preferred level of version stability:
- Pin to a specific version (e.g., `1.8.13`) for maximum stability
- Pin to a minor version (e.g., `1.8`) to receive patch updates only
- Pin to a major version (e.g., `1`) to receive minor and patch updates, but not major version changes
- Use `latest` to always get the most recent version

## Using Apprise for Notifications

To enhance your experience with Borgmatic, we'll show you a quick example of how to use Apprise for notifications. Apprise is a versatile tool that integrates with a variety of services and is built into Borgmatic. With the upcoming version 1.8.4 also natively. Here's a quick example of how you can use Apprise.

### Basic Setup

#### Cronjob Configuration

In an unmodified Borgmatic installation, your `crontab.txt` might look something like this:

```
0 1 * * * /usr/local/bin/borgmatic --stats -v 0 2>&1
```

To incorporate Apprise notifications, you can modify it like this:

```
*/5 * * * * PATH=$PATH:/usr/local/bin /usr/local/bin/borgmatic --stats -v 0 > /tmp/backup_run.log
```

#### Borgmatic Configuration

Add the following lines to your Borgmatic configuration file (`config.yaml`):

```yaml
before_backup:
  - echo "Starting a backup job."

after_backup:
  - echo "Backup created."
  - apprise -vv -t "✅ SUCCESS" -b "$(cat /tmp/backup_run.log)" "mailtos://smtp.example.com:587?user=server@example.com&pass=YourSecurePassword&from=server@example.com&to=receiver@example.com"

on_error:
  - echo "Error while creating a backup."
  - apprise -vv -t "❌ FAILED" -b "$(cat /tmp/backup_run.log)" "mailtos://smtp.example.com:587?user=server@example.com&pass=YourSecurePassword&from=server@example.com&to=receiver@example.com"
```

##### Note:

If you don't want to send the log file, you can replace `-b "$(cat /tmp/backup_run.log)"` with a custom message like `-b "My message"`.

### Advanced Options

##### Apprise Capabilities

Apprise offers a variety of services to send notifications to, such as Telegram, Slack, Discord, and many more. For a complete list, visit the [Apprise GitHub page](https://github.com/caronc/apprise#productivity-based-notifications).

#### Example for Multiple Services

Apprise allows you to notify multiple services at the same time:

```yaml
after_backup:
  - echo "Backup created."
  - apprise -vv -t "✅ SUCCESS" -b "$(cat /tmp/backup_run.log)" "mailtos://smtp.example.com:587?user=server@example.com&pass=YourSecurePassword&from=server@example.com&to=receiver@example.com,slack://token@Txxxx/Bxxxx/Cxxxx"
```

### Native Apprise Configuration in Borgmatic 1.8.4+

Starting from version 1.8.4, Borgmatic has native support for Apprise within its configuration. This makes it even easier to set up notifications. Below is how you can add Apprise directly to your Borgmatic `config.yaml`.

```yaml
apprise:
    states:
        - start
        - finish
        - fail

    services:
        - url: mailtos://smtp.example.com:587?user=server@example.com&pass=YourSecurePassword&from=server@example.com&to=receiver@example.com
          label: mail
        - url: slack://token@Txxxx/Bxxxx/Cxxxx
          label: slack

    start:
        title: ⚙️ Started
        body: Starting backup process.

    finish:
        title: ✅ SUCCESS
        body: Backups successfully made.

    fail:
        title: ❌ FAILED
        body: Your backups have failed.
```

And as of borgmatic 1.8.9+, borgmatic's logs are automatically appended to the `body` for each notification.

### Conclusion

Apprise provides a flexible and powerful way to handle notifications in Borgmatic. Be sure to check out the [official Apprise documentation](https://github.com/caronc/apprise#productivity-based-notifications) for a full range of options and capabilities.


## Other usage methods

### Run borgmatic like a binary through a container
This image can be used to run borgmatic like a binary by passing the borgmatic command while running the container. It allows you to isolate your system and execute borgmatic commands without directly installing borgmatic on your host system and only keeping persistent data.

To execute borgmatic commands, you can run your container by passing borgmatic subcommands:
```
docker run --rm -it \
MOUNT_FLAGS_HERE \
ghcr.io/borgmatic-collective/borgmatic \
list
```

**NOTE** Replace `MOUNT_FLAGS_HERE` placeholder with appropriate [mount flags](#volumes) and optionally [environment flags](#environment). [See above](#getting-started) for more clues.

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

**Tip** You can view list of available command line options in [borgmatic's docs](https://torsion.org/borgmatic/docs/reference/command-line/)

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

Use docker compose for easily management of your borgmatic container. You can also use this image with your existing docker-compose configuration to immediate setup backups for your deployed containers and/or the host.

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

## Advanced ##

#### Starting and stopping containers from hooks

In case you are using the container to backup docker volumes used by other containers, you might
want to make sure that the data is consistent and doesn't change while the backup is running. The
easiest way to ensure this is to stop the affected containers before the backup and restart them
afterwards.

There are two ways to achieve the start and stops. The first [use Docker CLI](#option-1-using-docker-cli). The second [Use Docker HTTP-POST API](#option-2-using-docker-http-post-api).

You can use the appropriate [borgmatic hooks](https://torsion.org/borgmatic/docs/how-to/add-preparation-and-cleanup-steps-to-backups/) and
[control the docker engine through the API](https://docs.docker.com/engine/api/), or via the docker client labrary (see options) using the hosts
docker socket.

Please note that you might want to prefer the `*_everything` hooks to the `*_backup` hooks, as
`after_backup` will not run if the backup fails for any reason (missing disk space, etc.) and
therefore the containers stay stopped.

First mount the docker socket from the host by adding `-v /var/run/docker.sock:/var/run/docker.sock`
to your `run` command or in the volume list of your `docker-compose.yml`.

Now, pick one of these two options.

##### Option 1 Using Docker CLI

Add the following environment to your docker run command line ``-e DOCKERCLI='true'``
to your `run` command or in the enviroment section of your `docker-compose.yml`. This is in addition to the above mentioned socket to add.

Now the docker command is available in your container. 

Then add the following in your config.yaml:
```
...
constants:
  ...
  containernames: "container-a container-b container c"
...
before_backup:
  - echo {containernames} | xargs -n 1 echo | tac | xargs docker stop

after_backup:
  - echo {containernames} | xargs docker start
...
```
This way all the containers are stopped in reverse order before the backup, and restarted in order after the backup. This way, for instance, you can ensure the back-end gets stopped last and started first.

**Note**: Make sure you put the names of the containers in a single, quoted string, separated by spaces, as the *containernames* constant shows.

##### Option 2 Using Docker HTTP-POST API

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

### Mount an archive as FUSE filesystem

While the parameters defined in above examples are sufficient for regular backups, following additional privileges will
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
[Backup Docker using borgmatic](https://www.modem7.com/books/docker-backup/page/backup-docker-using-borgmatic) - Thank you [@modem7](https://github.com/modem7)
