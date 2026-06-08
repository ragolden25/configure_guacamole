#!/usr/bin/env bash
set -euo pipefail

# Detect latest nginx version from Docker Hub
REPO="docker.io/library/nginx"

TAGS_JSON=$(skopeo list-tags docker://$REPO)
TAGS=($(echo "$TAGS_JSON" | jq -r '.Tags[]'))

SEMVER=($(printf "%s\n" "${TAGS[@]}" \
    | grep -vE '(dev|test|debug|rc|beta|alpha)' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V))

if [[ ${#SEMVER[@]} -eq 0 ]]; then
    echo "ERROR: No valid semver tags found for $REPO" >&2
    exit 5
fi

VERSION="${SEMVER[-1]}"

# Write VERSION file
QUARTER="$(cat /opt/ansible/files/common/current_quarter)"
BUILD_DIR="/opt/ansible/files/build/nginx/${QUARTER}"

mkdir -p "$BUILD_DIR"
echo "$VERSION" > "$BUILD_DIR/VERSION"

# Output version for Ansible
echo "$VERSION"
