#!/usr/bin/env bash
# Fail if uv.toml [pip] python-version differs from Dockerfile ARG PYTHON_VERSION.
# The Dockerfile is the source of truth.
# Usage: check-python-version-sync.sh [Dockerfile] [uv.toml]
# Needs only bash and coreutils. No network, no uv.
set -euo pipefail
set +x

dockerfile="${1:-Dockerfile}"
uv_toml="${2:-uv.toml}"

err() {
  echo "::error file=$1::$2"
  exit 1
}

for f in "$dockerfile" "$uv_toml"; do
  [[ -r "$f" ]] || err "$f" "File not found or unreadable: $f"
done

# First ARG PYTHON_VERSION=<value> in the Dockerfile.
docker_ver=""
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  if [[ "$line" =~ ^[[:space:]]*ARG[[:space:]]+PYTHON_VERSION=[\"\']?([^\"\'[:space:]]+) ]]; then
    docker_ver="${BASH_REMATCH[1]}"
    break
  fi
done <"$dockerfile"
[[ -n "$docker_ver" ]] || err "$dockerfile" "ARG PYTHON_VERSION=<version> not found in $dockerfile."

# python-version = "<value>" inside the [pip] table of uv.toml.
uv_ver=""
section=""
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  if [[ "$line" =~ ^[[:space:]]*\[([^]]+)\] ]]; then
    section="${BASH_REMATCH[1]}"
  elif [[ "$section" == "pip" && "$line" =~ ^[[:space:]]*python-version[[:space:]]*=[[:space:]]*[\"\']([^\"\']+)[\"\'] ]]; then
    uv_ver="${BASH_REMATCH[1]}"
    break
  fi
done <"$uv_toml"
[[ -n "$uv_ver" ]] || err "$uv_toml" "python-version not found under [pip] in $uv_toml."

if [[ "$uv_ver" != "$docker_ver" ]]; then
  err "$uv_toml" "python-version $uv_ver does not match Dockerfile PYTHON_VERSION $docker_ver. The Dockerfile ARG is the source of truth: update $uv_toml to match, then regenerate requirements.txt with uv pip compile."
fi

echo "uv.toml python-version $uv_ver matches Dockerfile PYTHON_VERSION."
