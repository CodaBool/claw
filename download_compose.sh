#!/usr/bin/env bash
set -euo pipefail

arch="aarch64"
tag="$(
  curl -fsSLI -o /dev/null -w '%{url_effective}' \
    https://github.com/docker/compose/releases/latest \
  | sed 's#.*/tag/##'
)"

curl -fsSL \
  "https://github.com/docker/compose/releases/download/${tag}/docker-compose-linux-${arch}" \
  -o ./ami/docker-compose

chmod +x ./ami/docker-compose
echo "Downloaded ${tag}"
