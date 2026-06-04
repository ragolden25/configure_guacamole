#!/bin/bash
set -euo pipefail

VERSION="$1"
QUARTER="$2"

BUILD_ROOT="/opt/ansible/files/build/postgres/${QUARTER}"

cd "${BUILD_ROOT}"

echo "Building Postgres HARDENED ${VERSION} for ${QUARTER}..."

docker build \
  --build-arg DEBIAN_VERSION="13" \
  --build-arg POSTGRES_VERSION="${VERSION}" \
  -t "nucleus/postgres:${VERSION}" \
  -f Dockerfile.postgres.hardened \
  .

echo "${VERSION}" > "${BUILD_ROOT}/VERSION.hardened"

echo "Postgres hardened ${VERSION} build complete."
