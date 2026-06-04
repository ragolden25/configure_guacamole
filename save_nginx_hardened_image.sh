#!/bin/bash
set -euo pipefail

VERSION="$1"
QUARTER="$2"

OUTPUT="/opt/ansible/files/avocado/${QUARTER}/images/nginx-hardened-${VERSION}.tar.gz"

docker save ccop/nginx-hardened:"${VERSION}" | gzip -c > "${OUTPUT}"

echo "Saved nginx hardened ${VERSION} to ${OUTPUT}"
