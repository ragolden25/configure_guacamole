predict_postgres.py
#!/usr/bin/env python3
import os
import sys
import datetime
import calendar

ENV_PATH = "/opt/ansible/files/avocado/postgres/calendar-pg.env"


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


def save_env(path, env, updates):
    lines = []
    with open(path) as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line or line.lstrip().startswith("#") or "=" not in line:
                lines.append(raw)
                continue

            k, _ = line.split("=", 1)
            key = k.strip()
            if key in updates:
                lines.append(f"{key}={updates[key]}\n")
            else:
                lines.append(raw)

    # Add any new keys that weren't present
    existing_keys = {l.split("=", 1)[0].strip()
                     for l in lines if "=" in l and not l.lstrip().startswith("#")}
    for k, v in updates.items():
        if k not in existing_keys:
            lines.append(f"{k}={v}\n")

    with open(path, "w") as f:
        f.writelines(lines)


def second_thursday(year, month):
    cal = calendar.monthcalendar(year, month)
    thursdays = [week[calendar.THURSDAY] for week in cal if week[calendar.THURSDAY] != 0]
    return thursdays[1]


def main():
    env = load_env(ENV_PATH)

    today = datetime.date.today()

    # Base anchors
    latest_major = int(env["PG_LATEST_MAJOR"])
    latest_minor = int(env["PG_LATEST_MINOR"])
    latest_version = env["PG_LATEST_VERSION"]

    support_years = int(env["PG_SUPPORT_YEARS"])
    minor_months = [int(m) for m in env["PG_MINOR_RELEASE_MONTHS"].split()]

    # --- 1. Handle possible MAJOR roll ---
    next_major = latest_major + 1
    next_major_key = f"PG_{next_major}_RELEASE_DATE"
    if next_major_key in env:
        next_major_release_date = datetime.datetime.strptime(
            env[next_major_key], "%Y-%m-%d"
        ).date()
        if today >= next_major_release_date:
            # Major has rolled
            latest_major = next_major
            latest_minor = 0
            latest_version = f"{latest_major}.0"

    # Recompute current major release date and EOL
    current_release_key = f"PG_{latest_major}_RELEASE_DATE"
    release_date = datetime.datetime.strptime(
        env[current_release_key], "%Y-%m-%d"
    ).date()
    eol_date = datetime.date(
        release_date.year + support_years,
        release_date.month,
        release_date.day,
    )

    # --- 2. Handle possible MINOR roll for current major ---
    # Find next minor release month/year based on today
    current_year = today.year
    current_month = today.month

    next_minor_month = None
    next_minor_year = current_year
    for m in minor_months:
        if m > current_month:
            next_minor_month = m
            break
    if next_minor_month is None:
        next_minor_month = minor_months[0]
        next_minor_year += 1

    next_minor_day = second_thursday(next_minor_year, next_minor_month)
    next_minor_date = datetime.date(next_minor_year, next_minor_month, next_minor_day)

    # Candidate next minor version
    candidate_minor = latest_minor + 1
    candidate_minor_version = f"{latest_major}.{candidate_minor}"

    # If we're past the next minor date and still within EOL, roll minor
    if next_minor_date <= today <= eol_date:
        latest_minor = candidate_minor
        latest_version = candidate_minor_version
        # After rolling, compute the *next* minor prediction
        # (for the following quarter)
        # Recompute next minor window from "today" again
        current_year = today.year
        current_month = today.month
        next_minor_month = None
        next_minor_year = current_year
        for m in minor_months:
            if m > current_month:
                next_minor_month = m
                break
        if next_minor_month is None:
            next_minor_month = minor_months[0]
            next_minor_year += 1
        next_minor_day = second_thursday(next_minor_year, next_minor_month)
        next_minor_date = datetime.date(next_minor_year, next_minor_month, next_minor_day)
        candidate_minor = latest_minor + 1
        candidate_minor_version = f"{latest_major}.{candidate_minor}"

    # --- 3. Compute predicted minor (future) ---
    if next_minor_date > eol_date:
        predicted_minor = "NONE"
    else:
        predicted_minor = candidate_minor_version

    # --- 4. Compute predicted major (future) ---
    predicted_major = f"{latest_major + 1}.0"

    # --- 5. Persist updates back into calendar-pg.env ---
    updates = {
        "PG_LATEST_MAJOR": str(latest_major),
        "PG_LATEST_MINOR": str(latest_minor),
        "PG_LATEST_VERSION": latest_version,
        "PREDICTED_MINOR_VERSION": predicted_minor,
        "PREDICTED_MAJOR_VERSION": predicted_major,
    }
    save_env(ENV_PATH, env, updates)

    # --- 6. Output EXACTLY ONE LINE for Ansible: the current effective version ---
    # e.g. "18.3", "18.4", "19.0"
    print(latest_version)


if __name__ == "__main__":
    main()
