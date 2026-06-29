# KeePassXC credential support

This image does not include `keepassxc-cli` by default because the only Alpine
package available (`keepassxc`) pulls in the full Qt6 GUI stack — adding
~150 MB to an image that is otherwise under 200 MB. That trade-off is not
reasonable for users who never touch KeePass.

Instead, this image ships a lightweight Python shim that replicates the exact
CLI interface that borgmatic calls. You opt in by mounting a single init script
at container startup. **No changes to borgmatic itself are needed.**

---

## How the shim works (note for borgmatic developers)

borgmatic calls `keepassxc-cli` like this:

```
keepassxc-cli show --show-protected --attributes Password \
    [--no-password] [--key-file /path/to/key] \
    /path/to/database.kdbx "entry-title"
```

The shim at `/usr/local/bin/keepassxc-cli` accepts the same arguments and
flags, uses [`pykeepass`](https://github.com/libkeepass/pykeepass) (a
pure-Python KeePass 4 reader) to open the database, and prints the requested
attribute to stdout — identical output to the real `keepassxc-cli`.

Because the interface is identical, borgmatic does not need to know or care
that it is talking to a Python script instead of the real binary. The
`keepassxc_cli_command` config option can be left at its default
(`keepassxc-cli`) since the shim is installed at the same path.

Supported flags: `--show-protected`, `--attributes`/`-a`, `--no-password`,
`--key-file`/`-k`, `--yubikey` (accepted silently — hardware tokens are not
supported). Attribute lookup covers `Password`, `UserName`, `URL`, `Notes`,
`Title`, and custom attributes. Group-path style entry names
(`Group/Entry`) are supported.

---

## Setup

### 1. Mount the init script

Add a volume mount to your `docker-compose.yml`:

```yaml
services:
  borgmatic:
    volumes:
      # ... your existing volumes ...
      - ./data/borgscripts/init-keepassxc-cli.sh:/custom-cont-init.d/init-keepassxc-cli.sh:ro
```

At startup the script installs `pykeepass` (~2 MB, no system packages) and
writes the `keepassxc-cli` shim to `/usr/local/bin/keepassxc-cli`.

### 2. Mount your KeePass database (and key file, if used)

```yaml
    volumes:
      - /path/to/your/passwords.kdbx:/etc/borgmatic/passwords.kdbx:ro
      - /path/to/your/passwords.keyx:/run/secrets/keepass.keyx:ro  # optional
```

Keep the database and key file outside your backup source so they are not
backed up to themselves.

### 3. Configure borgmatic

Add a `keepassxc:` block to your borgmatic config:

```yaml
keepassxc:
    database: /etc/borgmatic/passwords.kdbx

    # Set to false to use a key file instead of typing a password at startup.
    # Required for unattended/scheduled backups.
    ask_for_password: false

    # Optional — omit if your database is password-protected only.
    key_file: /run/secrets/keepass.keyx
```

Then reference credentials anywhere a password is expected:

```yaml
# Borg repository passphrase
encryption_passphrase: "{credential keepassxc /etc/borgmatic/passwords.kdbx MyBorgEntry}"

# Database hook credentials
postgresql_databases:
    - name: mydb
      username: "{credential keepassxc /etc/borgmatic/passwords.kdbx PostgresUser}"
      password: "{credential keepassxc /etc/borgmatic/passwords.kdbx PostgresPassword}"
```

The value in quotes (`MyBorgEntry`, `PostgresUser`, etc.) is the **title** of
the entry inside your KeePass database.

### 4. Verify at startup

When the container starts you should see:

```
[init-keepassxc-cli] Installing pykeepass...
[init-keepassxc-cli] Writing /usr/local/bin/keepassxc-cli shim...
[init-keepassxc-cli] Done. keepassxc-cli shim is ready.
```

Run a manual check to confirm borgmatic can reach the database:

```console
docker exec -it borgmatic borgmatic config validate
```

---

## Unattended backups and key files

`keepassxc-cli` normally prompts for the database master password interactively,
which breaks scheduled (cron) backups. Use a key file instead and set
`ask_for_password: false` in your borgmatic config — the shim will open the
database with the key file alone, no prompt.

Store the key file outside your container (e.g. in a Docker secret or a
host path not included in your backup source) and mount it read-only.

---

## Limitations

### Secret Service integration is not supported

borgmatic supports a `{credential keepassxc secret-service <key>}` syntax that
retrieves credentials via the D-Bus Secret Service API — the mechanism desktop
apps use to talk to a running KeePassXC or GNOME Keyring instance.

This does **not** work in a headless Docker container. The Secret Service API
requires a running D-Bus session bus and a Secret Service provider (KeePassXC
GUI or `gnome-keyring-daemon`) — neither of which exist in a container, and
providing them would pull in the full Qt6/GTK desktop stack that this shim
exists to avoid.

**For unattended Docker backups, use the key file approach** (`ask_for_password:
false` + `key_file`). It requires no interactive prompt and no running desktop
environment.

---

## Security notes

- The `pykeepass` library reads the KeePass 4 (`.kdbx`) format entirely
  in-process — the database is never sent anywhere.
- The shim prints the requested attribute to stdout exactly as
  `keepassxc-cli` does; borgmatic captures it in memory and never writes it
  to disk.
- `pykeepass` is installed at container startup rather than baked into the
  image, so it is covered by your normal image rebuild/update cycle via
  `docker compose pull`.
- Pin the version if you need reproducible builds:
  edit `init-keepassxc-cli.sh` and change
  `pip install pykeepass` to `pip install pykeepass==<version>`.