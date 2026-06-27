# Change Log
All notable changes to this project will be documented in this file.
 
The format is based on [Keep a Changelog](http://keepachangelog.com/).

## 2026-06-27 (continued 8)

### Changed

- `borgmatic` is now a thin wrapper around `borgmatic.bin` (the pip-installed binary), allowing the entrypoint to be intercepted cleanly without any behaviour change for users.

## 2026-06-27 (continued 7)

### Changed

- Reorder Dockerfile layers for better cache utilisation: `apk` packages now install before S6 overlay is added, and S6 is extracted in its own `RUN` step. Previously a S6 version bump invalidated the entire apk + pip chain; now each concern caches independently.
- Use `--mount=type=cache,id=apk-${TARGETARCH}` for the `apk` step (consistent with the existing pip cache mount).

## 2026-06-27 (continued 6)

### Fixed

- `renovate.json`: add `versioningTemplate: "loose"` to the S6 overlay custom manager. S6 uses 4-part version numbers (`3.2.0.2`) which aren't valid semver — without `loose` versioning Renovate silently skips S6 updates.

### Changed

- S6 overlay updated from `3.2.0.2` to `3.2.3.0`.

## 2026-06-27 (continued 5)

### Fixed

- `renovate.json`: constrain `PYTHON_VERSION` updates to major.minor only (`/^\d+\.\d+$/`), same as `ALPINE_VERSION`. Prevents Renovate proposing pre-release or Windows-variant tags like `3.15.0b3-windowsservercore-ltsc2025` which don't exist as valid Alpine-based Python images.

## 2026-06-27 (continued 4)

### Fixed

- `.drone.yml`: Drone tags file now written as a single comma-separated line (`latest,2.1.6-1.4.4`) rather than one tag per line. `thegeeklab/drone-docker-buildx` treated the entire file content as one string, causing an invalid tag error (`latest\n2.1.6-1.4.4`).

## 2026-06-27 (continued 3)

### Added

- `data/borgscripts/docker-stop.sh`: stops containers carrying a configurable label (`backup` by default) before a borgmatic run. Configurable label key and stop timeout. Requires `DOCKERCLI=true` and `docker.sock` mounted.
- `data/borgscripts/docker-start.sh`: starts a single compose stack after a borgmatic run using `docker compose start` (not `up -d`, so no unintended recreates). Configurable compose project directory. Requires `DOCKERCLI=true` and `docker.sock` mounted.
- `data/borgscripts/redis-backup.sh`: triggers `BGSAVE` on a Redis container and polls until the save completes before borgmatic runs. Configurable container name and timeout. The resulting `dump.rdb` is then included in borgmatic's normal source directory sweep.
- README: new "Example borgscripts" section covering all three scripts — configuration variables, label setup, borgmatic wiring, Docker requirements, and a note on AOF mode. New "Native database backup" section covering borgmatic's built-in PostgreSQL, MariaDB, MongoDB, and SQLite support.

## 2026-06-27 (continued 2)

### Added

- End-to-end CI tests that run borgmatic against a real Borg repository: full backup/restore cycle (repo-create → create → list → extract → verify file contents), `${VAR}` env var expansion in borgmatic config, and `encryption_passcommand` via a mounted secrets file.
- CI test that `borgmatic config validate` rejects invalid config with a non-zero exit code.

### Changed

- `base-fullbuild/` directory removed — all contents moved to repo root (`Dockerfile`, `requirements.txt`, `.env.template`, `data/`, `root/`) to match upstream structure. All CI, Drone, Renovate, and README references updated.
- `sync-drone-tags.yml` GitHub Actions workflow removed — redundant since `.drone.yml` now generates tags dynamically from `requirements.txt` at build time.
- Drone lint step removed — Hadolint and ShellCheck already run in GitHub Actions CI on every PR.

## 2026-06-27 (continued)

### Added

- `init-envfile` S6 oneshot service — processes `FILE__VARNAME` environment variables (LinuxServer.io convention) by reading the referenced file and writing its content into the S6 container environment before any other service starts. Complements the existing `BORG_PASSPHRASE_FILE` / `*_FILE` expansion. Dependency chain is now: `init-envfile → init-custom-packages → init-custom-scripts → init-config-end → svc-cron`.
- Renovate tracking for `ALPINE_VERSION` and `PYTHON_VERSION` — base image versions extracted as `ARG`s so Renovate can open PRs for each independently.
- Log rotation example (`logging: driver: local`) added to `docker-compose.yml` comments.
- `.gitignore` excluding `.claude` directory.

### Changed

- Base image updated from `python:3.14-alpine3.23` to `python:3.14-alpine3.24`.
- `S6_CMD_WAIT_FOR_SERVICES_MAXTIME` reverted to `0` (unlimited) — 30s could abort startup when `EXTRA_PKGS` installs large packages on a slow network.
- `docker-compose.restore.yml` — `/RestoreMount` renamed to `/mnt/restore` (consistent with main compose and README); `BORG_PASSPHRASE` added (required to decrypt repo when mounting archives); shell changed from `/bin/sh` to `/bin/bash`.
- `VOLUME_RESTORE` renamed to `BORG_RESTORE` in restore compose and `.env.template` (consistent with `BORG_*` naming convention).
- `docker-compose.yml` — expanded commented examples covering `BORG_SOURCE_*`, `BORG_REPO`, `BORG_HEALTHCHECK_URL`, `CRON`/`CRON_COMMAND`, `EXTRA_CRON` multi-line syntax, borgscripts volume, docker.sock, and `custom-cont-init.d`.
- Borgmatic config examples (`config.yaml`, `config.yaml.example`, `config.full.yaml.example`) updated to borgmatic 2.x format — deprecated `location:`, `storage:`, `retention:`, `consistency:` sections removed; all keys promoted to top level; `repositories:` now uses `{path:, label:}` objects; `checks:` uses `{name:, frequency:}` objects.
- All hook examples updated from deprecated `before_everything`/`after_everything`/`on_error` keys to the borgmatic 2.x `commands:` syntax with `before:`/`after:` timing levels and `states:` filters.
- Hook script examples (`before-backup.example`, `after-backup.example`, `failed-backup.example`) rewritten — label-based container selection (`docker ps -f label=backup | xargs --no-run-if-empty docker stop`), `docker compose start` for restart, `#!/bin/bash` shebangs replacing `with-contenv sh`.
- README — added Configuration section (example files table, env var expansion, Healthchecks.io integration); Hook scripts section (label-based stop pattern, borgscripts volume, backing up Docker compose files); log rotation under Logging; expanded restore section with shell access walkthrough. All hook examples updated to `commands:` syntax.
- `.drone.yml` — tags now generated dynamically from `requirements.txt` via a prepare step writing a `.tags` file; `no_cache: false` and `compress: true` removed; `PUSHRM_SHORT` updated.

## 2026-06-27

### Added

- `borgmatic-start` wrapper script — forwards SIGTERM/INT/HUP to borgmatic when the container is stopped, allowing in-progress backups to exit cleanly and release repository locks. The default cron command now uses `borgmatic-start` instead of `borgmatic` directly. A warning is printed at startup if the active crontab calls `borgmatic` directly.
- `/custom-cont-init.d/` support — mount a directory of `.sh` scripts that run after package installation but before cron starts, in filename order. Was previously documented but not wired up.
- `svc-cron-log` S6 logging pipeline — prefixes every log line from crond and borgmatic with an ISO timestamp before writing to Docker's log driver.
- `init-custom-scripts` S6 oneshot service — the new service that executes custom init scripts, inserted between `init-custom-packages` and `init-config-end` in the dependency chain.
- `svc-cron/timeout-down` — tells S6 to wait 5 seconds for crond to exit after SIGTERM before escalating to SIGKILL.
- Renovate tracking for `S6_OVERLAY_VERSION` — automatic update PRs when new S6 releases drop.
- `stop_grace_period: 10m` added to `docker-compose.yml`.
- State volume (`/root/.local/state/borgmatic`) added to `docker-compose.yml` and `.env.template`.
- `restart: unless-stopped` added to `docker-compose.yml`.
- `version:` field removed from both compose files (deprecated in Compose v2).

### Changed

- `svc-cron/run` — `compgen -e` replaces `set | grep` for safe secret variable expansion (immune to multi-line values); indirect expansion `${!var}` replaces `eval`; `EXTRA_CRON` append now uses `printf` to guarantee a leading newline; debug labels corrected to show "Before"/"After"; `debug_secrets()` function deduplicated; dead `CRON="${CRON:-...}"` branch removed (S6 treats empty env vars as unset).
- Default cron fallback — when no `CRON` env var and no `crontab.txt` is present, the container now falls back to a default schedule of `0 1 * * *` with a log message, rather than silently failing to open `crontab.txt`.
- `init-custom-packages/run` — `EXTRA_PKGS` now split via `read -ra` to avoid fragile unquoted word splitting; `--no-cache` added to both `apk add` calls.
- `svc-cron/finish` — now distinguishes clean stop, error exit, and signal crash with a specific log message for each.
- `Dockerfile` — removed `TERM=xterm` from baked-in `ENV`; `S6_CMD_WAIT_FOR_SERVICES_MAXTIME` raised from `0` (infinite) to `30000` ms; S6 tarballs cleaned up after extraction; `bash-doc` removed; redundant second `apk upgrade` removed.
- README rewritten to reflect current architecture, S6 features, signal handling, secret files, scheduling modes, Apprise notifications, and restore procedure.
- `.env.template` — removed deprecated `VOLUME_DOT_BORGMATIC`; added `VOLUME_BORGMATIC_STATE`.

### Fixed

- CI expanded from a bare build check to a full test suite covering binary versions, config validation, S6/cron configuration, secret file expansion, custom init scripts, timestamped logging, and SIGTERM signal forwarding.