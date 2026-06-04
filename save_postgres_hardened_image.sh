#!/bin/bash
set -euo pipefail

VERSION="$1"
QUARTER="$2"

OUTPUT="/opt/ansible/files/avocado/${QUARTER}/images/nucleus-postgres-${VERSION}.tar.gz"

docker save nucleus/postgres:"${VERSION}" | gzip -c > "${OUTPUT}"

echo "Saved hardened Postgres ${VERSION} to ${OUTPUT}"
