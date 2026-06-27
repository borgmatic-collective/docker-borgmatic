#!/bin/bash
# Optional custom init script — mount at /custom-cont-init.d/init-keepassxc-cli.sh
#
# Installs a lightweight keepassxc-cli shim using pykeepass (pure Python,
# no Qt/GUI dependencies) so borgmatic can retrieve credentials from a
# KeePass database.
#
# Usage in borgmatic config:
#   keepassxc:
#     keepassxc_cli_command: /usr/local/bin/keepassxc-cli
#     database: /path/to/passwords.kdbx
#     ask_for_password: false       # use key_file instead
#     key_file: /run/secrets/keepass.keyx   # optional
#
# Then reference credentials in your config:
#   encryption_passphrase: "{credential keepassxc /path/to/passwords.kdbx MyEntry}"

set -e

echo "[init-keepassxc-cli] Installing pykeepass..."
pip install --quiet --no-cache-dir pykeepass

echo "[init-keepassxc-cli] Writing /usr/local/bin/keepassxc-cli shim..."
cat > /usr/local/bin/keepassxc-cli << 'SHIM'
#!/usr/bin/env python3
"""
Minimal keepassxc-cli shim backed by pykeepass.
Implements the subset of keepassxc-cli that borgmatic calls:
  keepassxc-cli show --show-protected --attributes <attr>
                     [--no-password] [--key-file <file>]
                     <database> <entry>
"""
import argparse
import sys

try:
    from pykeepass import PyKeePass
    from pykeepass.exceptions import CredentialsError
except ImportError:
    print("pykeepass is not installed", file=sys.stderr)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command")                          # 'show'
    parser.add_argument("--show-protected", action="store_true")
    parser.add_argument("--attributes", "-a", default="Password")
    parser.add_argument("--no-password", action="store_true")
    parser.add_argument("--key-file", "-k", default=None)
    parser.add_argument("--yubikey", default=None)          # unsupported, accepted silently
    parser.add_argument("database")
    parser.add_argument("entry")
    args = parser.parse_args()

    if args.command != "show":
        print(f"Unsupported command: {args.command}", file=sys.stderr)
        sys.exit(1)

    password = None if args.no_password else input("Enter password to unlock database: ")

    try:
        kp = PyKeePass(args.database, password=password, keyfile=args.key_file)
    except CredentialsError:
        print("Error: invalid credentials for KeePass database", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    # Search by title; support group/title path (e.g. "Group/Entry")
    parts = args.entry.rsplit("/", 1)
    if len(parts) == 2:
        entries = kp.find_entries(title=parts[1], group=kp.find_groups(name=parts[0], first=True), first=True)
    else:
        entries = kp.find_entries(title=args.entry, first=True)

    if entries is None:
        print(f"Error: entry '{args.entry}' not found in database", file=sys.stderr)
        sys.exit(1)

    attr = args.attributes
    value = None

    if attr == "Password":
        value = entries.password
    elif attr == "UserName":
        value = entries.username
    elif attr == "URL":
        value = entries.url
    elif attr == "Notes":
        value = entries.notes
    elif attr == "Title":
        value = entries.title
    else:
        # Custom attribute
        value = entries.custom_properties.get(attr)

    if value is None:
        print(f"Error: attribute '{attr}' not found on entry '{args.entry}'", file=sys.stderr)
        sys.exit(1)

    print(value)


if __name__ == "__main__":
    main()
SHIM

chmod +x /usr/local/bin/keepassxc-cli
echo "[init-keepassxc-cli] Done. keepassxc-cli shim is ready."
