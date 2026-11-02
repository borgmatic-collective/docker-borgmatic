#!/usr/bin/env bash
# warn/err only print file names, they never write to them.
# shellcheck disable=SC2094
# Fail if requirements.txt (uv lockfile) is stale against requirements.in.
# Usage: check-lock-fresh.sh [requirements.in] [requirements.txt]
# Needs only bash and coreutils. No network, no uv.
set -euo pipefail
set +x

in_file="${1:-requirements.in}"
txt_file="${2:-requirements.txt}"
failures=0

err() {
  echo "::error file=$1::$2"
  failures=$((failures + 1))
}

warn() {
  echo "::warning file=$1::$2"
}

# Lowercase, collapse runs of - _ . into a single -.
normalise() {
  local n="${1,,}"
  n="$(printf '%s' "$n" | tr -s '._-' '-')"
  # tr -s only squeezes repeats of the same char, so squeeze mixed runs too.
  while [[ "$n" == *--* ]]; do n="${n//--/-}"; done
  printf '%s' "$n"
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

for f in "$in_file" "$txt_file"; do
  if [[ ! -r "$f" ]]; then
    err "$f" "File not found or unreadable: $f"
  fi
done
if ((failures > 0)); then
  exit 1
fi

# Collect pins and index URLs from the lockfile.
declare -A lock_pins=()
declare -A lock_urls=()
hash_count=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  t="$(trim "$line")"
  case "$t" in
    --hash=sha256:*) hash_count=$((hash_count + 1)) ;;
  esac
  if [[ "$t" =~ ^--extra-index-url([[:space:]]+|=)([^[:space:]]+) ]]; then
    lock_urls["${BASH_REMATCH[2]}"]=1
  fi
  # Pin lines start at column 0: name==version then space, backslash, ; or EOL.
  if [[ "$line" =~ ^([A-Za-z0-9][A-Za-z0-9._-]*)==([^[:space:]\\\;]+) ]]; then
    key="$(normalise "${BASH_REMATCH[1]}")==${BASH_REMATCH[2]}"
    lock_pins["$key"]=1
  fi
done <"$txt_file"

# Check each line of the input file.
lineno=0
pin_count=0
while IFS= read -r line || [[ -n "$line" ]]; do
  lineno=$((lineno + 1))
  line="${line%$'\r'}"
  # Drop full-line and inline comments.
  if [[ "$line" =~ ^[[:space:]]*# ]]; then continue; fi
  line="${line%%[[:space:]]#*}"
  t="$(trim "$line")"
  [[ -z "$t" ]] && continue

  if [[ "$t" =~ ^--extra-index-url([[:space:]]+|=)([^[:space:]]+)$ ]]; then
    url="${BASH_REMATCH[2]}"
    if [[ -z "${lock_urls[$url]+x}" ]]; then
      err "$txt_file" "--extra-index-url $url from $in_file is missing in $txt_file. Recompile with --emit-index-url."
    fi
    continue
  fi

  if [[ "$t" =~ ^([A-Za-z0-9][A-Za-z0-9._-]*)(\[[^]]*\])?[[:space:]]*==[[:space:]]*([^[:space:]\;]+)[[:space:]]*(\;.*)?$ ]]; then
    name="$(normalise "${BASH_REMATCH[1]}")"
    ver="${BASH_REMATCH[3]}"
    pin_count=$((pin_count + 1))
    if [[ -z "${lock_pins["$name==$ver"]+x}" ]]; then
      err "$txt_file" "$name==$ver (from $in_file line $lineno) not found in $txt_file. Lockfile is stale; re-run uv pip compile."
    fi
    continue
  fi

  warn "$in_file" "Line $lineno not understood, skipped: $t"
done <"$in_file"

if ((pin_count == 0)); then
  warn "$in_file" "No pins found in $in_file."
fi

if ((hash_count == 0)); then
  err "$txt_file" "No --hash=sha256: lines in $txt_file. Compile with --generate-hashes."
fi

if ((failures > 0)); then
  echo "Lockfile check failed with $failures error(s)."
  exit 1
fi

echo "Lockfile $txt_file is fresh against $in_file ($pin_count pins, $hash_count hashes)."
