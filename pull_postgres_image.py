#!/usr/bin/env bash
set -euo pipefail

TAG="$1"
REPO="nginx"

docker pull "${REPO}:${TAG}"

# Re-tag as ccop/nginx:<TAG>
docker tag "nginx:${TAG}" "ccop/nginx:${TAG}"
[root@ansible scripts]# cat pull_postgres_image.py
#!/usr/bin/env python3
import os
import subprocess
import sys

ENV_PATH = "/opt/ansible/files/avocado/postgres/calendar-pg.env"
PREDICT_SCRIPT = "/opt/ansible/files/avocado/scripts/predict_postgres.py"

def load_env(path):
    env = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    return env

def save_env(path, env):
    with open(path, "w") as f:
        f.write("# === PostgreSQL Release Anchors ===\n")
        for key in sorted(env.keys()):
            f.write(f"{key}={env[key]}\n")

def docker_pull(version):
    print(f"Attempting pull for PostgreSQL {version}...")
    result = subprocess.run(
        ["docker", "pull", f"postgres:{version}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    return result.returncode == 0

def main():
    # Run predictor to update env with new predictions
    pred = subprocess.run(
        [PREDICT_SCRIPT],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    if pred.returncode != 0:
        print("ERROR: predictor failed")
        print(pred.stderr)
        sys.exit(1)

    # Reload env after predictor updated it
    env = load_env(ENV_PATH)

    predicted_minor = env.get("PREDICTED_MINOR_VERSION")
    predicted_major = env.get("PREDICTED_MAJOR_VERSION")
    latest_version = env.get("PG_LATEST_VERSION")

    # Try predicted minor first
    if predicted_minor and docker_pull(predicted_minor):
        major, minor = predicted_minor.split(".")
        env["PG_LATEST_MAJOR"] = major
        env["PG_LATEST_MINOR"] = minor
        env["PG_LATEST_VERSION"] = predicted_minor
        save_env(ENV_PATH, env)
        print("SUCCESS:", predicted_minor)
        sys.exit(0)

    # Try last known working minor
    if latest_version and docker_pull(latest_version):
        major, minor = latest_version.split(".")
        env["PG_LATEST_MAJOR"] = major
        env["PG_LATEST_MINOR"] = minor
        env["PG_LATEST_VERSION"] = latest_version
        save_env(ENV_PATH, env)
        print("SUCCESS:", latest_version)
        sys.exit(0)

    # Try predicted major
    if predicted_major and docker_pull(predicted_major):
        major, minor = predicted_major.split(".")
        env["PG_LATEST_MAJOR"] = major
        env["PG_LATEST_MINOR"] = minor
        env["PG_LATEST_VERSION"] = predicted_major
        save_env(ENV_PATH, env)
        print("SUCCESS:", predicted_major)
        sys.exit(0)

    print("ERROR: No valid PostgreSQL versions found.")
    sys.exit(1)

if __name__ == "__main__":
    main()
