#!/usr/bin/env bash
set -euo pipefail

REPO="docker.io/library/nginx"

# List tags from Docker Hub
TAGS_JSON=$(skopeo list-tags docker://$REPO)
TAGS=($(echo "$TAGS_JSON" | jq -r '.Tags[]'))

# Filter semver tags only
SEMVER=($(printf "%s\n" "${TAGS[@]}" \
    | grep -vE '(dev|test|debug|rc|beta|alpha)' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V))

if [[ ${#SEMVER[@]} -eq 0 ]]; then
    echo "ERROR: No valid semver tags found for $REPO" >&2
    exit 5
fi

echo "${SEMVER[-1]}"
