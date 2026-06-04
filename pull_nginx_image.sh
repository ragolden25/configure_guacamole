#!/usr/bin/env bash
set -euo pipefail

TAG="$1"
REPO="nginx"

docker pull "${REPO}:${TAG}"

# Re-tag as ccop/nginx:<TAG>
docker tag "nginx:${TAG}" "ccop/nginx:${TAG}"
