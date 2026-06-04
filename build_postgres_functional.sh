#!/bin/bash
set -euo pipefail

VERSION="$1"
QUARTER="$2"

BUILD_ROOT="/opt/ansible/files/build/postgres/${QUARTER}"

cd "${BUILD_ROOT}"

echo "Building Postgres FUNCTIONAL ${VERSION} for ${QUARTER}..."

docker build \
  --build-arg DEBIAN_VERSION="13" \
  --build-arg POSTGRES_VERSION="${VERSION}" \
  -t "ccop/postgres:${VERSION}" \
  -f Dockerfile.postgres.functional \
  .

echo "${VERSION}" > "${BUILD_ROOT}/VERSION.functional"

echo "Postgres functional ${VERSION} build complete."
