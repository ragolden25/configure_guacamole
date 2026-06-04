#!/bin/bash
set -euo pipefail

VERSION="$1"
QUARTER="$2"

OUTPUT="/opt/ansible/files/avocado/${QUARTER}/images/nginx-functional-${VERSION}.tar.gz"

docker save ccop/nginx-functional:"${VERSION}" | gzip -c > "${OUTPUT}"

echo "Saved nginx functional ${VERSION} to ${OUTPUT}"
