#!/bin/sh
set -e

if [ "${AUTO_SIGNUP_ON_EMPTY_DB:-True}" = "True" ]; then
  USER_COUNT="$(
    python - <<'PY' 2>/dev/null || echo 0
import os
import sqlite3

db_path = "/app/backend/data/webui.db"
count = 0

if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    try:
        count = cur.execute("select count(*) from user").fetchone()[0]
    except Exception:
        count = 0
    finally:
        conn.close()

print(count)
PY
  )"

  if [ "${USER_COUNT:-0}" -eq 0 ]; then
    export ENABLE_SIGNUP=True
    echo "[open-webui-init] first run detected: ENABLE_SIGNUP=True"
  else
    export ENABLE_SIGNUP=False
    echo "[open-webui-init] users found (${USER_COUNT}): ENABLE_SIGNUP=False"
  fi
fi

exec bash start.sh
