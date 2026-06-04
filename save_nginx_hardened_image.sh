#!/bin/bash
set -euo pipefail

VERSION="$1"
QUARTER="$2"

OUTPUT="/opt/ansible/files/avocado/${QUARTER}/images/nucleus-nginx-${VERSION}.tar.gz"

docker save nucleus/nginx-hardened:"${VERSION}" | gzip -c > "${OUTPUT}"

echo "Saved hardened nginx ${VERSION} to ${OUTPUT}"
