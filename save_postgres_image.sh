#!/usr/bin/env bash
set -euo pipefail

TAG="$1"        # e.g. 18.3
QUARTER="$2"    # e.g. fy26q3

OUT="/opt/ansible/files/avocado/${QUARTER}/images/postgres-${TAG}.tar.gz"
TMPDIR="$(mktemp -d)"

# 1. Load the tarball (if it exists)
if [[ -f "$OUT" ]]; then
    echo "Loading existing postgres tarball: $OUT"
    docker load -i "$OUT" > "${TMPDIR}/load.out"
else
    echo "No existing tarball found. Proceeding with current local image."
fi

# 2. Detect the actual loaded tag (if any)
ACTUAL_TAG=""
if [[ -f "${TMPDIR}/load.out" ]]; then
    # docker load output looks like: "Loaded image: postgres:18.3"
    ACTUAL_TAG=$(grep -oE 'postgres:[0-9]+\.[0-9]+' "${TMPDIR}/load.out" || true)
fi

# 3. If ACTUAL_TAG is empty, fall back to local docker images
if [[ -z "$ACTUAL_TAG" ]]; then
    ACTUAL_TAG=$(docker images --format '{{.Repository}}:{{.Tag}}' \
        | grep '^postgres:' \
        | grep "${TAG}" \
        | head -n1 || true)
fi

if [[ -z "$ACTUAL_TAG" ]]; then
    echo "ERROR: Could not determine actual postgres tag after load."
    exit 1
fi

echo "Detected actual postgres tag: $ACTUAL_TAG"

# 4. Expected normalized tag
EXPECTED_TAG="ccop/postgres:${TAG}"

# 5. Normalize tag if needed
if [[ "$ACTUAL_TAG" != "$EXPECTED_TAG" ]]; then
    echo "Normalizing tag: $ACTUAL_TAG → $EXPECTED_TAG"
    docker tag "$ACTUAL_TAG" "$EXPECTED_TAG"
    docker image rm "$ACTUAL_TAG"
else
    echo "Tag already normalized: $EXPECTED_TAG"
fi

# 6. Save the normalized image
echo "Saving normalized postgres image to: $OUT"
docker save "$EXPECTED_TAG" | gzip -c > "$OUT.tmp"

# 7. Atomic replace (prevents partial writes)
mv "$OUT.tmp" "$OUT"

echo "Postgres image saved cleanly as: $OUT"

# 8. Cleanup
rm -rf "$TMPDIR"
