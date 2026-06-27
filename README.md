# Borgmatic Container

[![GitHub issues](https://img.shields.io/github/issues/borgmatic-collective/docker-borgmatic)](https://github.com/borgmatic-collective/docker-borgmatic/issues)
[![GitHub stars](https://img.shields.io/github/stars/borgmatic-collective/docker-borgmatic)](https://github.com/borgmatic-collective/docker-borgmatic/stargazers)
[![Docker Stars](https://img.shields.io/docker/stars/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)
[![Docker Pulls](https://img.shields.io/docker/pulls/b3vis/borgmatic)](https://hub.docker.com/r/b3vis/borgmatic)
[![GitHub last commit](https://img.shields.io/github/last-commit/borgmatic-collective/docker-borgmatic)](https://github.com/borgmatic-collective/docker-borgmatic)

Running on [S6 Overlay](https://github.com/just-containers/s6-overlay). Supports `linux/amd64` and `linux/arm64`.

Includes [Borg](https://github.com/borgbackup/borg), [Borgmatic](https://github.com/borgmatic-collective/borgmatic), [Apprise](https://github.com/caronc/apprise), and optional Docker CLI for container stop/start hooks.

---

## Tags

| Tag | Description |
| :---: | --- |
| `latest` | Latest Borgmatic + Borg |
| `2.x.x-1.x.x` | Specific Borgmatic–Borg version pair |

---

## Quick start

```yaml
services:
  borgmatic:
    image: ghcr.io/borgmatic-collective/borgmatic:latest
    container_name: borgmatic
    volumes:
      - /home:/mnt/source:ro
      - ./data/repository:/mnt/borg-repository
      - ./data/borgmatic.d:/etc/borgmatic.d/
      - ./data/.config/borg:/root/.config/borg
      - ./data/.ssh:/root/.ssh
      - ./data/.cache/borg:/root/.cache/borg
      - ./data/.state/borgmatic:/root/.local/state/borgmatic
    environment:
      - TZ=Europe/London
      - BORG_PASSPHRASE=changeme
    restart: unless-stopped
    stop_grace_period: 10m
```

Copy `.env.template` to `.env`, fill in your values, then:

```console
docker compose up -d
```

---

## First run

Initialise your Borg repository:

```console
docker exec -it borgmatic borgmatic init --encryption repokey-blake2
```

Run a manual backup to verify everything works:

```console
docker exec -it borgmatic borgmatic --stats -v 1 --files
```

Generate a full example config:

```console
docker exec borgmatic borgmatic config generate -d /etc/borgmatic.d/config.yaml
```

> **Archive naming gotcha:** By default borgmatic uses `{hostname}` in archive names. Docker container hostnames change on every rebuild, which breaks pruning and compaction. Set an explicit archive name in your config:
> ```yaml
> archive_name_format: 'myhost-{now:%Y-%m-%d-%H%M%S}'
> ```

---

## Configuration

### Example files

The image ships example configs in `/etc/borgmatic.d/` that you can use as a starting point. When you mount your own config directory, place your config there:

| File | Purpose |
| --- | --- |
| `config.yaml` | Minimal working config for a local repository |
| `config.yaml.example` | Remote repository with SSH and passcommand |
| `config.full.yaml.example` | Annotated reference covering all common options |
| `before-backup.example` | Hook script template run before each backup |
| `after-backup.example` | Hook script template run after each successful backup |
| `failed-backup.example` | Hook script template run on error |

To use the hook scripts, make them executable and reference them in your config:

```yaml
commands:
  - before: everything
    run:
        - /etc/borgmatic.d/before-backup
  - after: everything
    states: [finish]
    run:
        - /etc/borgmatic.d/after-backup
  - after: everything
    states: [fail]
    run:
        - /etc/borgmatic.d/failed-backup
```

### Environment variable expansion

Borgmatic expands `${VAR}` references inside config files at runtime, which is useful for keeping secrets and paths out of your committed config:

```yaml
source_directories:
    - ${BORG_SOURCE_1}
    - ${BORG_SOURCE_2}

repositories:
    - path: ${BORG_REPO}
      label: remote
```

Pass them via your compose file:

```yaml
environment:
  - BORG_SOURCE_1=/mnt/data
  - BORG_SOURCE_2=/mnt/media
  - BORG_REPO=user@borg.example.com:myrepo
```

### Healthchecks.io

Borgmatic has built-in [Healthchecks.io](https://healthchecks.io) integration. Add your ping URL to your config:

```yaml
healthchecks:
    ping_url: ${BORG_HEALTHCHECK_URL}
```

```yaml
environment:
  - BORG_HEALTHCHECK_URL=https://hc-ping.com/your-uuid-here
```

Borgmatic will ping on start, success, and failure automatically.

---

## Environment variables

| Variable | Description | Default |
| :---: | --- | --- |
| `TZ` | Container timezone | `Europe/London` |
| `BORG_PASSPHRASE` | Repository encryption passphrase | — |
| `BORG_PASSPHRASE_FILE` | Path to a file containing the passphrase (see [Secret files](#secret-files)) | — |
| `BORG_RSH` | SSH command for remote repos, e.g. `ssh -i /root/.ssh/id_ed25519 -p 50221` | — |
| `CRON` | Cron schedule for borgmatic (see [Scheduling](#scheduling)) | — |
| `CRON_COMMAND` | Command cron runs | `borgmatic-start --stats -v 0 2>&1` |
| `EXTRA_CRON` | Additional cron lines appended verbatim | — |
| `DOCKERCLI` | Set to `true` to install Docker CLI and Compose at startup | — |
| `EXTRA_PKGS` | Space-separated Alpine packages to install at startup | — |
| `DEBUG_SECRETS` | Set to `true` or `1` to log secret variable values before/after expansion | — |

Any Borg or borgmatic environment variable is passed through automatically — see the [borgmatic](https://torsion.org/borgmatic/) and [Borg](https://borgbackup.readthedocs.io/) documentation for the full list.

---

## Scheduling

Three modes, checked in this order:

**1. `CRON` environment variable**

Standard 5-field cron expression:

```yaml
environment:
  - CRON=0 2 * * *
```

**2. `crontab.txt` file**

Mount a file at `/etc/borgmatic.d/crontab.txt`. Use `borgmatic-start` (not `borgmatic`) to keep signal handling working:

```
0 2 * * * borgmatic-start --stats -v 0 2>&1
```

**3. Built-in default**

If neither `CRON` nor `crontab.txt` is present, borgmatic runs daily at 01:00.

**Extra jobs** with `EXTRA_CRON`:

```yaml
environment:
  - EXTRA_CRON=0 6 * * 0 borgmatic-start --stats -v 0 2>&1
```

**Disable cron** entirely:

```yaml
environment:
  - CRON=false
```

---

## Signal handling

The container uses `borgmatic-start` as the default cron command. When `docker stop` sends SIGTERM, `borgmatic-start` forwards it to borgmatic so an in-progress backup can exit cleanly and release its repository lock rather than being killed mid-run.

Set `stop_grace_period` to give borgmatic enough time to finish:

```yaml
services:
  borgmatic:
    stop_grace_period: 10m   # adjust to suit your backup size and speed
```

The container will print a warning at startup if it detects `borgmatic` being called directly (instead of `borgmatic-start`) in the active crontab.

---

## Secret files

Any `BORG_*` or `YOUR_*` environment variable ending in `_FILE` is read from the named file and exported as the base variable at startup. This is the recommended approach for Docker Swarm secrets or any secret management system that writes files:

```yaml
environment:
  - BORG_PASSPHRASE_FILE=/run/secrets/borg_passphrase
secrets:
  - borg_passphrase
```

If both `BORG_PASSPHRASE` and `BORG_PASSPHRASE_FILE` are set, the file value takes precedence.

### Manual commands with secrets

When running borgmatic manually via `docker exec`, secrets are already available in the S6 container environment:

```console
docker exec borgmatic sh -c \
  'export BORG_PASSPHRASE=$(cat /run/s6/container_environment/BORG_PASSPHRASE) \
   && borgmatic list'
```

---

## Custom init scripts

Mount a directory to `/custom-cont-init.d/` containing `.sh` scripts. They run after packages are installed but before cron starts, in filename order. Useful for generating SSH keys, importing GPG keys, or any one-time setup:

```yaml
volumes:
  - ./my-init-scripts:/custom-cont-init.d:ro
```

Scripts run as root. A non-zero exit code logs a warning but does not abort startup.

---

## Volumes

| Path | Description |
| :---: | --- |
| `/mnt/source` | Data to back up — mount read-only for safety |
| `/mnt/borg-repository` | Local Borg repository |
| `/etc/borgmatic.d/` | Borgmatic config files and optional `crontab.txt` |
| `/root/.config/borg` | Borg config and keyfiles — **back these up** |
| `/root/.ssh` | SSH keys for remote repositories |
| `/root/.cache/borg` | Borg chunk cache (speeds up deduplication) |
| `/root/.local/state/borgmatic` | Borgmatic state for periodic check tracking |
| `/custom-cont-init.d/` | Custom init scripts (optional) |

---

## Notifications with Apprise

Apprise is included and integrates with Telegram, Slack, Discord, email, and [many more services](https://github.com/caronc/apprise#productivity-based-notifications).

Add notification hooks to your borgmatic config:

```yaml
commands:
  - after: everything
    states: [fail]
    run:
        - apprise -vv -t "Backup FAILED" -b "Borgmatic error on $(hostname)" \
            "mailtos://smtp.example.com:587?user=you@example.com&pass=secret&to=you@example.com"
```

Or use borgmatic's native Apprise config (borgmatic 1.8.4+):

```yaml
apprise:
  services:
    - url: slack://token@Txxxx/Bxxxx/Cxxxx
      label: slack
    - url: mailtos://smtp.example.com:587?user=you@example.com&pass=secret&to=you@example.com
      label: email
  states:
    - start
    - finish
    - fail
  finish:
    title: Backup succeeded
  fail:
    title: Backup failed
```

Borgmatic's logs are automatically appended to notification bodies from borgmatic 1.8.9+.

---

## Docker CLI support

Set `DOCKERCLI=true` to install Docker CLI and Compose at startup, then mount the Docker socket to allow borgmatic hooks to stop and start other containers:

```yaml
environment:
  - DOCKERCLI=true
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

Rather than hardcoding container names, label the services you want paused during backup and let the scripts discover them automatically:

```yaml
# in each service that should pause during backup:
services:
  myapp:
    labels:
      - backup
```

The image ships ready-to-use `docker-stop.sh` and `docker-start.sh` scripts in `data/borgscripts/` — see [Example borgscripts](#example-borgscripts) for setup details. For quick inline use:

```yaml
commands:
  - before: everything
    run:
        - docker ps -q -f "label=backup" | xargs --no-run-if-empty docker container stop -t 60
  - after: everything
    states: [finish, fail]
    run:
        - docker compose --project-directory /opt/docker/mystack start
```

Using `states: [finish, fail]` on the start command ensures containers are never left stopped, even if the backup fails.

Without Docker CLI, you can still control containers via the socket API directly:

```yaml
commands:
  - before: everything
    run:
        - 'echo -ne "POST /v1.41/containers/mycontainer/stop HTTP/1.1\r\nHost: localhost\r\n\r\n" | nc local:/var/run/docker.sock 80 > /dev/null'
  - after: everything
    states: [finish, fail]
    run:
        - 'echo -ne "POST /v1.41/containers/mycontainer/start HTTP/1.1\r\nHost: localhost\r\n\r\n" | nc local:/var/run/docker.sock 80 > /dev/null'
```

> Use `after: everything` with `states: [finish, fail]` to restart containers whether the backup succeeded or failed.

---

## Soft failure for intermittent targets

If a backup target is not always available (removable drive, remote server), use a `before: action` command with exit code 75 to skip gracefully without triggering error notifications:

```yaml
commands:
  - before: action
    when: [create]
    run:
        - findmnt /mnt/backup-drive > /dev/null || exit 75
```

See the [borgmatic soft failure docs](https://torsion.org/borgmatic/reference/configuration/command-hooks/#soft-failure) and [backup to a removable drive](https://torsion.org/borgmatic/how-to/backup-to-a-removable-drive-or-an-intermittent-server/) for more.

---

## FUSE restore

Mounting a Borg archive requires extra privileges. Use the provided restore compose override:

```console
docker compose down
docker compose -f docker-compose.yml -f docker-compose.restore.yml run borgmatic
```

The restore compose override sets `command: /bin/sh`, so the container drops you straight into a shell. If you need to attach to an already-running container instead:

```console
docker exec -it borgmatic /bin/bash
```

Once inside, mount the archive, copy your files, then clean up:

```console
# list available archives
borg list /mnt/borg-repository

# mount a specific archive (or the whole repo to browse all archives)
mkdir -p /mnt/restore
borg mount /mnt/borg-repository::archive-name /mnt/restore

# copy files back to their original location or inspect them
cp -a /mnt/restore/path/to/file /original/path/

# unmount and exit when done
borg umount /mnt/restore
exit
```

The required capabilities (`SYS_ADMIN`, `/dev/fuse`, AppArmor/SELinux options) are pre-configured in `docker-compose.restore.yml`.

If Borg has a stale lock from a previously interrupted backup:

```console
borg break-lock /mnt/borg-repository
```

---

## Running borgmatic as a one-shot command

The image can be used without cron — pass borgmatic subcommands directly:

```console
docker run --rm -it \
  -v /home:/mnt/source:ro \
  -v ./data/repository:/mnt/borg-repository \
  -v ./data/borgmatic.d:/etc/borgmatic.d/ \
  -v ./data/.config/borg:/root/.config/borg \
  -e BORG_PASSPHRASE=changeme \
  ghcr.io/borgmatic-collective/borgmatic \
  borgmatic list
```

---

## Logging

All output is timestamped by the S6 logging pipeline and sent to Docker's log driver:

```console
docker logs borgmatic
docker logs -f borgmatic   # follow
```

Borgmatic can be verbose. Add a log rotation policy to prevent Docker logs from growing unboundedly:

```yaml
services:
  borgmatic:
    logging:
      driver: local
      options:
        max-size: 10m
        max-file: "3"
```

Enable debug logging for secret variable expansion:

```yaml
environment:
  - DEBUG_SECRETS=true
```

---

## Hook scripts

Hook scripts can live anywhere accessible to the container. A dedicated volume keeps them separate from borgmatic config:

```yaml
volumes:
  - ./data/borgscripts:/borgscripts:ro
```

```yaml
commands:
  - before: everything
    run:
        - /borgscripts/docker-stop.sh
  - after: everything
    states: [finish, fail]
    run:
        - /borgscripts/docker-start.sh
```

Make sure the scripts are executable (`chmod +x`). The container ships ready-to-use example scripts in `data/borgscripts/` — copy them into your own `borgscripts/` directory and edit the configuration variables at the top of each file.

The container also ships minimal hook templates in `/etc/borgmatic.d/` (`before-backup.example`, `after-backup.example`, `failed-backup.example`).

---

## Example borgscripts

The following scripts are provided in `data/borgscripts/`. They all require `DOCKERCLI=true` and the Docker socket mounted:

```yaml
environment:
  - DOCKERCLI=true
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  - ./data/borgscripts:/borgscripts:ro
```

### docker-stop.sh — pause containers before backup

Stops any container carrying a `backup` label before borgmatic runs. Using a label rather than hardcoded names means you only need to update your other compose files, not this script, when services change.

Label the services you want paused in their own compose files:

```yaml
services:
  myapp:
    labels:
      - backup
  mydb:
    labels:
      - backup
```

The script has two configuration variables at the top:

```bash
BACKUP_LABEL="backup"   # label key to filter containers — change if you use a different label
STOP_TIMEOUT=60         # seconds to wait for graceful shutdown before force-kill
```

### docker-start.sh — resume containers after backup

Starts a compose stack after borgmatic finishes. Uses `docker compose start` rather than `up -d` to restart only containers that were previously running — it will not recreate services, pull new images, or start anything that was already stopped before the backup began.

Edit the configuration variable at the top:

```bash
COMPOSE_DIR="/opt/docker/mystack"   # absolute path to your compose project directory
```

Wire both scripts together in your borgmatic config. Using `states: [finish, fail]` on the start command ensures containers are never left stopped, even when a backup errors:

```yaml
commands:
  - before: everything
    run:
        - /borgscripts/docker-stop.sh
  - after: everything
    states: [finish, fail]
    run:
        - /borgscripts/docker-start.sh
```

### redis-backup.sh — snapshot Redis before backup

Redis supports live backups via `BGSAVE` — the container does not need to stop. This script triggers a background save and waits for it to complete. When borgmatic runs immediately after, it backs up the resulting `dump.rdb` as a regular file.

Configuration variables at the top:

```bash
REDIS_CONTAINER="redis"   # name or ID of the Redis container
WAIT_TIMEOUT=120          # max seconds to wait for BGSAVE to finish
```

You need to mount the Redis data directory into the borgmatic container as a source, and include it in your borgmatic config:

```yaml
# docker-compose.yml (borgmatic service)
volumes:
  - /opt/docker/mystack/redis/data:/mnt/source/redis:ro
```

```yaml
# borgmatic config
source_directories:
    - /mnt/source/redis   # directory containing dump.rdb
```

```yaml
# borgmatic hooks
commands:
  - before: everything
    run:
        - /borgscripts/redis-backup.sh
```

> **Note:** If Redis is configured with `appendonly yes`, the AOF file is what matters, not dump.rdb. In that case, stop the container before backup and start it again after — the `docker-stop.sh` / `docker-start.sh` pair handles this if the Redis container carries the `backup` label.

---

## Native database backup (borgmatic)

For PostgreSQL, MariaDB/MySQL, MongoDB, and SQLite, borgmatic has built-in support that dumps the database and includes the dump in the archive — no separate script needed. Example for PostgreSQL:

```yaml
postgresql_databases:
    - name: mydb
      hostname: db
      username: postgres
      password: ${POSTGRES_PASSWORD}
      format: custom
```

See the [borgmatic database documentation](https://torsion.org/borgmatic/how-to/backup-your-databases/) for the full list of supported databases and options.

---

### Backing up Docker configuration

Mount your compose files read-only into the container as a backup source:

```yaml
volumes:
  - /opt/docker/mystack/docker-compose.yml:/mnt/source/docker/docker-compose.yml:ro
  - /opt/docker/mystack/.env:/mnt/source/docker/.env:ro
```

Then include `/mnt/source/docker` in your `source_directories`. This ensures your Docker stack definition is included in every backup alongside your data.
