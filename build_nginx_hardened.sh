#!/bin/bash
set -euo pipefail

VERSION="$1"
QUARTER="$2"

BUILD_ROOT="/opt/ansible/files/build/nginx/${QUARTER}"

cd "${BUILD_ROOT}"

echo "Building nginx HARDENED ${VERSION} for ${QUARTER}..."

docker build \
  --build-arg DEBIAN_VERSION="13" \
  -t "ccop/nginx-hardened:${VERSION}" \
  -f Dockerfile.nginx.hardened \
  .

echo "${VERSION}" > "${BUILD_ROOT}/VERSION.hardened"

echo "nginx hardened ${VERSION} build complete."
