#!/bin/bash
set -euo pipefail

VERSION="$1"
QUARTER="$2"

BUILD_ROOT="/opt/ansible/files/build/nginx/${QUARTER}"

cd "${BUILD_ROOT}"

echo "Building nginx FUNCTIONAL ${VERSION} for ${QUARTER}..."

docker build \
  --build-arg DEBIAN_VERSION="13" \
  -t "ccop/nginx-functional:${VERSION}" \
  -f Dockerfile.nginx.functional \
  .

echo "${VERSION}" > "${BUILD_ROOT}/VERSION.functional"

echo "nginx functional ${VERSION} build complete."
