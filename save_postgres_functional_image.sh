#!/bin/bash
set -euo pipefail

VERSION="$1"
QUARTER="$2"

OUTPUT="/opt/ansible/files/avocado/${QUARTER}/images/ccop-postgres-${VERSION}.tar.gz"

docker save ccop/postgres:"${VERSION}" | gzip -c > "${OUTPUT}"

echo "Saved functional Postgres ${VERSION} to ${OUTPUT}"
