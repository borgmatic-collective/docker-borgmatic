#!/usr/bin/env bash
# Round-trip test: backup then restore through /init (S6) and the
# repo compose files, the same path users take.
# Also checks: container exit codes, backup via borgmatic-start (the
# cron path), a FILE__ secret reaching a real backup, and prune plus
# compact followed by a restore.
# Usage: test-backup-restore.sh <image-tag>
# Needs docker, the compose plugin and passwordless sudo
# (the container writes root-owned files).
set -euo pipefail
set +x

if (($# != 1)) || [[ -z "$1" ]]; then
  echo "Usage: $0 <image-tag>" >&2
  exit 2
fi
image="$1"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
passphrase="test-restore-passphrase"
project="borgmatic-restore-test-$$"
failures=0
current_stage=""

in_ci() {
  [[ -n "${GITHUB_ACTIONS:-}" ]]
}

stage() {
  end_stage
  current_stage="$1"
  if in_ci; then
    echo "::group::$1"
  else
    echo
    echo "==== $1 ===="
  fi
}

end_stage() {
  if [[ -n "$current_stage" ]] && in_ci; then
    echo "::endgroup::"
  fi
  current_stage=""
}

err() {
  failures=$((failures + 1))
  if in_ci; then
    echo "::error title=test-backup-restore::$1"
  else
    echo "ERROR: $1" >&2
  fi
}

notice() {
  if in_ci; then
    echo "::notice title=test-backup-restore::$1"
  else
    echo "NOTE: $1"
  fi
}

# Stop at the first failed stage; later stages depend on earlier ones.
die() {
  err "$1"
  end_stage
  echo "Restore test failed with $failures error(s)."
  exit 1
}

workdir="$(mktemp -d "${TMPDIR:-/tmp}/borgmatic-restore-test.XXXXXX")"

cleanup() {
  local rc=$?
  docker compose -p "$project" down --remove-orphans >/dev/null 2>&1 || true
  sudo rm -rf -- "$workdir"
  exit "$rc"
}
trap cleanup EXIT

source_dir="$workdir/source"
data_dir="$workdir/data"
restore_dir="$workdir/restore"
rc_dir="$workdir/rc"
env_file="$workdir/.env"
override="$workdir/docker-compose.override.yml"

compose() {
  docker compose -p "$project" \
    --project-directory "$repo_root" \
    -f "$repo_root/docker-compose.yml" \
    -f "$repo_root/docker-compose.restore.yml" \
    -f "$override" \
    --env-file "$env_file" "$@"
}

# Older images reported 143 for every one-shot run (crond's SIGTERM
# overwrote the exit code). The stages below record the CMD exit code
# in a file so they do not depend on that. The "Exit codes" and
# "borgmatic-start" stages read the real docker exit code, so they
# need the fixed image.
# Wraps a command so it writes its exit code to /rc/<name>.
# shellcheck disable=SC2016
rc_wrap='n="$1"; shift; rc=0; "$@" || rc=$?; echo "$rc" >"/rc/$n"; exit "$rc"'

# Read /rc/<name>; a missing file means the command never ran.
read_rc() {
  local f="$rc_dir/$1"
  if sudo test -s "$f"; then
    sudo cat -- "$f"
  else
    echo "missing"
  fi
}

# run_svc <service> <name> <cmd...>: run through compose, print the rc.
run_svc() {
  local svc="$1" name="$2"
  shift 2
  sudo rm -f -- "$rc_dir/$name"
  compose run --rm -T -e CRON=false -v "$rc_dir:/rc" "$svc" \
    bash -c "$rc_wrap" _ "$name" "$@" >&2 || true
  read_rc "$name"
}

# expect_ok <rc> <message>: fail the run unless rc is 0.
expect_ok() {
  if [[ "$1" != "0" ]]; then
    die "$2 (exit code: $1)."
  fi
}

# check_ok <rc> <message>: like expect_ok, but only records the error
# and returns 1, so a stage can stop without ending the run.
check_ok() {
  if [[ "$1" != "0" ]]; then
    err "$2 (exit code: $1)."
    return 1
  fi
}

# run_direct <name> <repo-dir> <conf-dir> [docker args...] -- <cmd...>
# Plain docker run with the borgmatic volumes, a chosen repo and config
# dir, and no BORG_PASSPHRASE unless passed in the docker args.
# Prints the CMD exit code recorded in /rc/<name>.
run_direct() {
  local name="$1" repo="$2" conf="$3"
  shift 3
  local -a dargs=()
  while (($# > 0)) && [[ "$1" != "--" ]]; do
    dargs+=("$1")
    shift
  done
  if (($# > 0)); then
    shift
  fi
  sudo rm -f -- "$rc_dir/$name"
  docker run --rm --hostname borgmatic -e CRON=false -e TZ=Etc/UTC \
    -v "$rc_dir:/rc" \
    -v "$source_dir:/mnt/source:ro" \
    -v "$repo:/mnt/borg-repository" \
    -v "$restore_dir:/mnt/restore" \
    -v "$conf:/etc/borgmatic.d/" \
    -v "$data_dir/.config/borg:/root/.config/borg" \
    -v "$data_dir/.ssh:/root/.ssh" \
    -v "$data_dir/.cache/borg:/root/.cache/borg" \
    ${dargs[@]+"${dargs[@]}"} \
    "$image" bash -c "$rc_wrap" _ "$name" "$@" >&2 || true
  read_rc "$name"
}

# Writes `borgmatic repo-list --json` to /rc/<name>.json.
# shellcheck disable=SC2016
list_json='borgmatic repo-list --json >"/rc/$1.json"'

# count_archives <name>: print the archive count in /rc/<name>.json,
# or fail if the file is missing or not valid JSON.
count_archives() {
  local f="$rc_dir/$1.json"
  sudo test -s "$f" || return 1
  sudo cat -- "$f" | python3 -c '
import json, sys
data = json.load(sys.stdin)
print(sum(len(r.get("archives", [])) for r in data))
'
}

# check_tree <dir> <label>: compare checksums of <dir> to the source.
check_tree() {
  local dir="$1" label="$2" want_sums got_sums
  if ! sudo test -d "$dir"; then
    err "$label: extract missing: $dir"
    return 1
  fi
  want_sums="$(cd "$source_dir" && find . -type f -print0 | sort -z |
    xargs -0 sha256sum)"
  # shellcheck disable=SC2016
  got_sums="$(sudo bash -c 'cd "$1" && find . -type f -print0 | sort -z |
    xargs -0 sha256sum' _ "$dir")" || got_sums=""
  if [[ "$want_sums" == "$got_sums" ]]; then
    echo "OK: $label: checksums match ($(wc -l <<<"$want_sums") files)."
  else
    err "$label: checksums differ from source."
    diff <(echo "$want_sums") <(echo "$got_sums") || true
    return 1
  fi
}

stage "Setup test fixtures"
# borgmatic extract needs the --destination dir to exist already.
mkdir -p "$source_dir/sub/deeper" "$rc_dir" \
  "$restore_dir/single" "$restore_dir/full" "$restore_dir/wronghost" \
  "$restore_dir/badpath" "$restore_dir/secret" "$restore_dir/pruned" \
  "$data_dir/repository" "$data_dir/borgmatic.d" "$data_dir/.config/borg" \
  "$data_dir/.ssh" "$data_dir/.cache/borg" "$data_dir/.state/borgmatic" \
  "$data_dir/repository2" "$data_dir/borgmatic-prune.d"

known_content="borgmatic restore round trip $(date -u +%Y%m%dT%H%M%SZ)"
printf '%s\n' "$known_content" >"$source_dir/sub/f.txt"
printf 'top level file\n' >"$source_dir/top.txt"
printf 'nested file\n' >"$source_dir/sub/deeper/nested.txt"
head -c 65536 /dev/urandom >"$source_dir/sub/random.bin"
printf 'name with spaces\n' >"$source_dir/sub/with space.txt"

cat >"$data_dir/borgmatic.d/config.yaml" <<'EOF'
source_directories:
  - /mnt/source
repositories:
  - path: /mnt/borg-repository
    label: test
keep_daily: 7
EOF

# Same config, but keep_secondly 1 so prune has something to remove.
# borgmatic has no keep_last; archives made in different seconds plus
# keep_secondly 1 keeps only the newest one.
cat >"$data_dir/borgmatic-prune.d/config.yaml" <<'EOF'
source_directories:
  - /mnt/source
repositories:
  - path: /mnt/borg-repository
    label: test
keep_secondly: 1
EOF

# Passphrase for the second repo, given only as a FILE__ secret.
secret_file="$workdir/secret-passphrase"
printf '%s\n' "file-secret-passphrase-$$" >"$secret_file"

cat >"$env_file" <<EOF
TZ=Etc/UTC
BORG_PASSPHRASE=$passphrase
VOLUME_SOURCE=$source_dir
VOLUME_TARGET=$data_dir/repository
VOLUME_ETC_BORGMATIC=$data_dir/borgmatic.d
VOLUME_BORG_CONFIG=$data_dir/.config/borg
VOLUME_SSH=$data_dir/.ssh
VOLUME_BORG_CACHE=$data_dir/.cache/borg
VOLUME_BORGMATIC_STATE=$data_dir/.state/borgmatic
BORG_RESTORE=$restore_dir
EOF

cat >"$override" <<EOF
services:
  borgmatic:
    image: $image
  borgmaticrestore:
    image: $image
EOF

if ! docker image inspect "$image" >/dev/null 2>&1; then
  die "Image $image not found locally. Build or pull it first."
fi
compose config --quiet || die "docker compose config failed."
echo "Work dir: $workdir"
echo "Image:    $image"

stage "Backup: repo-create and create (borgmatic service)"
rc="$(run_svc borgmatic repo-create borgmatic repo-create --encryption repokey)"
expect_ok "$rc" "borgmatic repo-create failed"
rc="$(run_svc borgmatic create borgmatic create --stats)"
expect_ok "$rc" "borgmatic create failed"
rc="$(run_svc borgmatic repo-list borgmatic repo-list)"
expect_ok "$rc" "borgmatic repo-list failed"
echo "OK: repository created and archive written."

stage "Extract: single path (borgmaticrestore service)"
rc="$(run_svc borgmaticrestore extract-single borgmatic extract \
  --archive latest --path mnt/source/sub/f.txt \
  --destination /mnt/restore/single)"
expect_ok "$rc" "borgmatic extract of a single path failed"
restored="$restore_dir/single/mnt/source/sub/f.txt"
if ! sudo test -f "$restored"; then
  err "Restored file missing: $restored"
else
  got="$(sudo cat -- "$restored")"
  if [[ "$got" == "$known_content" ]]; then
    echo "OK: restored f.txt matches known content."
  else
    err "Restored f.txt differs. Expected '$known_content', got '$got'."
  fi
fi
# Only the requested path should come back.
if sudo test -e "$restore_dir/single/mnt/source/top.txt"; then
  err "Single-path extract also restored top.txt."
fi

stage "Extract: whole archive (borgmaticrestore service)"
rc="$(run_svc borgmaticrestore extract-full borgmatic extract \
  --archive latest --destination /mnt/restore/full)"
expect_ok "$rc" "borgmatic extract of the whole archive failed"
full="$restore_dir/full/mnt/source"
if ! sudo test -d "$full"; then
  err "Whole-archive extract missing: $full"
else
  want_sums="$(cd "$source_dir" && find . -type f -print0 | sort -z |
    xargs -0 sha256sum)"
  # shellcheck disable=SC2016
  got_sums="$(sudo bash -c 'cd "$1" && find . -type f -print0 | sort -z |
    xargs -0 sha256sum' _ "$full")"
  if [[ "$want_sums" == "$got_sums" ]]; then
    echo "OK: whole-archive checksums match ($(wc -l <<<"$want_sums") files)."
  else
    err "Whole-archive checksums differ from source."
    diff <(echo "$want_sums") <(echo "$got_sums") || true
  fi
fi

stage "FUSE mount (borgmaticrestore service)"
if [[ ! -e /dev/fuse ]]; then
  notice "Skipping FUSE test: /dev/fuse is not present on this host."
else
  # Runs inside the container. The EXIT trap records the rc on any
  # exit path and always tries to unmount.
  # shellcheck disable=SC2016
  fuse_script='
set -euo pipefail
mounted=0
finish() {
  rc=$?
  if ((mounted)); then
    borgmatic umount --mount-point /tmp/restore || rc=1
  fi
  echo "$rc" >/rc/fuse
  exit "$rc"
}
trap finish EXIT
mkdir -p /tmp/restore
borgmatic mount --archive latest --mount-point /tmp/restore
mounted=1
got="$(cat /tmp/restore/mnt/source/sub/f.txt)"
if [[ "$got" != "$EXPECTED" ]]; then
  echo "FUSE content mismatch: got [$got]" >&2
  exit 1
fi
ls -R /tmp/restore/mnt/source
echo "FUSE content matches."
'
  sudo rm -f -- "$rc_dir/fuse"
  compose run --rm -T -v "$rc_dir:/rc" -e EXPECTED="$known_content" \
    borgmaticrestore bash -c "$fuse_script" || true
  rc="$(read_rc fuse)"
  if [[ "$rc" == "0" ]]; then
    echo "OK: FUSE mount, read and umount worked."
  else
    err "FUSE mount test failed (exit code: $rc)."
  fi
fi

stage "Negative: --archive latest with the wrong hostname"
# Same volumes as the restore service, but a different hostname.
# 'latest' should match no archive, so extract must fail.
sudo rm -f -- "$rc_dir/wronghost"
docker run --rm --hostname other \
  -e BORG_PASSPHRASE="$passphrase" -e CRON=false -e TZ=Etc/UTC \
  -v "$rc_dir:/rc" \
  -v "$data_dir/repository:/mnt/borg-repository" \
  -v "$restore_dir:/mnt/restore" \
  -v "$data_dir/borgmatic.d:/etc/borgmatic.d/" \
  -v "$data_dir/.config/borg:/root/.config/borg" \
  -v "$data_dir/.ssh:/root/.ssh" \
  -v "$data_dir/.cache/borg:/root/.cache/borg" \
  "$image" bash -c "$rc_wrap" _ wronghost \
  borgmatic extract --archive latest --destination /mnt/restore/wronghost ||
  true
rc="$(read_rc wronghost)"
if [[ "$rc" == "missing" ]]; then
  err "Wrong-hostname extract did not run (no exit code recorded)."
elif [[ "$rc" == "0" ]]; then
  err "Extract with the wrong hostname succeeded; expected a failure."
elif sudo test -e "$restore_dir/wronghost/mnt/source/sub/f.txt"; then
  err "Extract with the wrong hostname failed but still restored files."
else
  echo "OK: extract with the wrong hostname failed as expected (exit $rc)."
fi

end_stage

stage "archive_hostname makes archive lookup independent of the container hostname"
sudo rm -f -- "$rc_dir/archhost"
sudo mkdir -p -- "$restore_dir/archhost"
docker run --rm --hostname other \
  -e BORG_PASSPHRASE="$passphrase" -e CRON=false -e TZ=Etc/UTC \
  -v "$rc_dir:/rc" \
  -v "$data_dir/repository:/mnt/borg-repository" \
  -v "$restore_dir:/mnt/restore" \
  -v "$data_dir/borgmatic.d:/etc/borgmatic.d/" \
  -v "$data_dir/.config/borg:/root/.config/borg" \
  -v "$data_dir/.ssh:/root/.ssh" \
  -v "$data_dir/.cache/borg:/root/.cache/borg" \
  "$image" bash -c "$rc_wrap" _ archhost \
  borgmatic --archive-hostname borgmatic extract --archive latest \
  --path mnt/source/sub/f.txt --destination /mnt/restore/archhost ||
  true
rc="$(read_rc archhost)"
if [[ "$rc" == "0" ]] && sudo test -e "$restore_dir/archhost/mnt/source/sub/f.txt"; then
  echo "OK: --archive-hostname found the archive from a different hostname."
else
  err "Extract with --archive-hostname failed (exit code: $rc)."
fi

end_stage

# The stages below are independent: each reports through err() and
# returns, so one failure does not stop the others.

# Exit code propagation. Reads the real docker exit code, no rc file.
test_exit_codes() {
  local spec cmd want rc inner
  for spec in "exit 7:7" "true:0" "false:1"; do
    cmd="${spec%:*}"
    want="${spec##*:}"
    rc=0
    docker run --rm -e CRON=false "$image" sh -c "$cmd" >/dev/null 2>&1 ||
      rc=$?
    if [[ "$rc" == "$want" ]]; then
      echo "OK: '$cmd' gave container exit code $rc."
    else
      err "'$cmd' gave container exit code $rc, expected $want."
    fi
  done

  # A failing borgmatic command must fail the container too. The rc
  # file holds borgmatic's own code; docker must report the same one.
  sudo rm -f -- "$rc_dir/badpath"
  rc=0
  compose run --rm -T -e CRON=false -v "$rc_dir:/rc" borgmaticrestore \
    bash -c "$rc_wrap" _ badpath \
    borgmatic extract --archive latest --path does/not/exist \
    --destination /mnt/restore/badpath >&2 || rc=$?
  inner="$(read_rc badpath)"
  if [[ "$inner" == "missing" ]]; then
    err "Failing extract did not run (docker exit code: $rc)."
  elif [[ "$inner" == "0" ]]; then
    err "Extract of a missing path succeeded; expected a failure."
  elif [[ "$rc" != "$inner" ]]; then
    err "Failing extract exited $inner, but the container exited $rc."
  else
    echo "OK: failing extract gave container exit code $rc."
  fi
}

# Backup through borgmatic-start, the wrapper cron uses.
test_borgmatic_start() {
  local rc before after
  rc="$(run_svc borgmatic list-start-before bash -c "$list_json" _ \
    list-start-before)"
  check_ok "$rc" "repo-list before borgmatic-start failed" || return 0
  before="$(count_archives list-start-before)" || {
    err "Could not read the archive count before borgmatic-start."
    return 0
  }

  rc=0
  compose run --rm -T -e CRON=false borgmatic \
    borgmatic-start create --stats -v 1 >&2 || rc=$?
  check_ok "$rc" "borgmatic-start create failed" || return 0

  rc="$(run_svc borgmatic list-start-after bash -c "$list_json" _ \
    list-start-after)"
  check_ok "$rc" "repo-list after borgmatic-start failed" || return 0
  after="$(count_archives list-start-after)" || {
    err "Could not read the archive count after borgmatic-start."
    return 0
  }
  if ((after == before + 1)); then
    echo "OK: borgmatic-start create added an archive ($before -> $after)."
  else
    err "borgmatic-start create: archive count $before -> $after, expected +1."
  fi
}

# FILE__BORG_PASSPHRASE on a second repo, with no BORG_PASSPHRASE set.
test_file_secret() {
  local repo2="$data_dir/repository2" conf="$data_dir/borgmatic.d" rc
  local -a secret=(-e FILE__BORG_PASSPHRASE=/run/secrets/pw
    -v "$secret_file:/run/secrets/pw:ro")

  rc="$(run_direct secret-init "$repo2" "$conf" "${secret[@]}" -- \
    borgmatic repo-create --encryption repokey)"
  check_ok "$rc" "repo-create with a FILE__ passphrase failed" || return 0
  rc="$(run_direct secret-create "$repo2" "$conf" "${secret[@]}" -- \
    borgmatic create --stats)"
  check_ok "$rc" "create with a FILE__ passphrase failed" || return 0
  rc="$(run_direct secret-extract "$repo2" "$conf" "${secret[@]}" -- \
    borgmatic extract --archive latest --destination /mnt/restore/secret)"
  check_ok "$rc" "extract with a FILE__ passphrase failed" || return 0
  check_tree "$restore_dir/secret/mnt/source" "FILE__ secret repo" ||
    return 0

  # Without the secret the same repo must not open.
  rc="$(run_direct secret-none "$repo2" "$conf" -- \
    timeout 60 borgmatic repo-list)"
  if [[ "$rc" == "missing" ]]; then
    err "repo-list without a passphrase did not run."
  elif [[ "$rc" == "0" ]]; then
    err "repo-list on the second repo worked without a passphrase."
  else
    echo "OK: second repo needs the passphrase (exit $rc without it)."
  fi
}

# prune and compact on the first repo, then restore what is left.
test_prune_compact() {
  local repo="$data_dir/repository" conf="$data_dir/borgmatic-prune.d"
  local rc i before after
  local -a pw=(-e BORG_PASSPHRASE="$passphrase")

  for i in 1 2 3; do
    rc="$(run_direct "prune-create-$i" "$repo" "$conf" "${pw[@]}" -- \
      borgmatic create)"
    check_ok "$rc" "create $i of 3 before prune failed" || return 0
    sleep 1
  done
  rc="$(run_direct list-prune-before "$repo" "$conf" "${pw[@]}" -- \
    bash -c "$list_json" _ list-prune-before)"
  check_ok "$rc" "repo-list before prune failed" || return 0
  before="$(count_archives list-prune-before)" || {
    err "Could not read the archive count before prune."
    return 0
  }
  if ((before < 3)); then
    err "Only $before archive(s) before prune; expected at least 3."
    return 0
  fi

  rc="$(run_direct prune "$repo" "$conf" "${pw[@]}" -- \
    borgmatic prune --list --stats)"
  check_ok "$rc" "borgmatic prune failed" || return 0
  rc="$(run_direct compact "$repo" "$conf" "${pw[@]}" -- \
    borgmatic compact)"
  check_ok "$rc" "borgmatic compact failed" || return 0

  rc="$(run_direct list-prune-after "$repo" "$conf" "${pw[@]}" -- \
    bash -c "$list_json" _ list-prune-after)"
  check_ok "$rc" "repo-list after prune failed" || return 0
  after="$(count_archives list-prune-after)" || {
    err "Could not read the archive count after prune."
    return 0
  }
  if ((after == 1)); then
    echo "OK: prune with keep_secondly 1 left 1 archive ($before -> $after)."
  else
    err "Prune left $after archive(s) from $before; expected 1."
    return 0
  fi

  rc="$(run_direct prune-extract "$repo" "$conf" "${pw[@]}" -- \
    borgmatic extract --archive latest --destination /mnt/restore/pruned)"
  check_ok "$rc" "extract after prune and compact failed" || return 0
  check_tree "$restore_dir/pruned/mnt/source" "after prune and compact" ||
    return 0
}

stage "Exit codes: container exit code matches the CMD"
test_exit_codes || true
end_stage

stage "Backup via borgmatic-start (the cron path)"
test_borgmatic_start || true
end_stage

stage "FILE__ secret: backup and restore on a second repo"
test_file_secret || true
end_stage

# Last, because it deletes archives from the first repo.
stage "prune and compact, then restore"
test_prune_compact || true
end_stage

if ((failures > 0)); then
  echo "Restore test failed with $failures error(s)."
  exit 1
fi

echo "Restore test passed: backup, extract, FUSE, hostname, exit code," \
  "borgmatic-start, FILE__ secret and prune/compact checks OK."
