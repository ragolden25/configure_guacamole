#!/usr/bin/env bash
set -euo pipefail

TAG="$1"
QUARTER="$2"

OUT="/opt/ansible/files/avocado/${QUARTER}/images/nginx-${TAG}.tar.gz"

docker save "ccop/nginx:${TAG}" | gzip -c > "${OUT}"
