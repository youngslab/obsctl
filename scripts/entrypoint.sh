#!/bin/bash
set -e

echo "[init-config] Starting initialization..."

# ---- PUID/PGID handling via usermod/groupmod ----
PUID=${PUID:-1000}
PGID=${PGID:-1000}

if [ "$PGID" != "1000" ]; then
    echo "[init-config] Setting obsidian group GID to $PGID"
    groupmod -o -g "$PGID" obsidian
fi

if [ "$PUID" != "1000" ]; then
    echo "[init-config] Setting obsidian user UID to $PUID"
    usermod -o -u "$PUID" obsidian
fi

# ---- Validate OneDrive credentials ----
# Skip validation if running a manual onedrive command (e.g., auth)
if [ ! -f /onedrive-conf/refresh_token ] && [ -z "${ONEDRIVE_AUTHRESPONSE:-}" ]; then
    echo "[init-config] WARNING: No OneDrive credentials found."
    echo "  Run: docker compose run --rm obsctl onedrive --confdir=/onedrive-conf --syncdir=/vault --synchronize --single-directory ''"
    echo "  to perform first-time authentication."
    echo "  Or set ONEDRIVE_AUTHRESPONSE environment variable."
    # Don't exit -- allow container to start for manual auth
fi

# ---- Copy OneDrive config defaults if not present ----
if [ ! -f /onedrive-conf/config ]; then
    echo "[init-config] Copying default OneDrive config to /onedrive-conf/config"
    cp /defaults/config/onedrive-config /onedrive-conf/config
    # Create backup so OneDrive doesn't detect a config change and demand --resync
    cp /onedrive-conf/config /onedrive-conf/config.backup
    # Remove stale sync state from prior auth runs
    rm -f /onedrive-conf/items.sqlite3
fi

# Ensure config.backup always exists to prevent --resync demands
if [ ! -f /onedrive-conf/config.backup ]; then
    cp /onedrive-conf/config /onedrive-conf/config.backup
    rm -f /onedrive-conf/items.sqlite3
fi

if [ ! -f /onedrive-conf/sync_list ]; then
    echo "[init-config] Copying default sync_list to /onedrive-conf/sync_list"
    cp /defaults/config/sync_list /onedrive-conf/sync_list
fi

# ---- Generate obsidian.json if not present ----
OBSIDIAN_CONFIG_DIR="/home/obsidian/.config/obsidian"
OBSIDIAN_JSON="${OBSIDIAN_CONFIG_DIR}/obsidian.json"

if [ ! -f "$OBSIDIAN_JSON" ]; then
    echo "[init-config] Generating obsidian.json..."
    VAULT_ID=$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c 16)
    TIMESTAMP=$(date +%s%3N)
    VAULT_NAME=${VAULT_NAME:-MyVault}

    jq -n \
        --arg vid "$VAULT_ID" \
        --arg vname "$VAULT_NAME" \
        --arg vpath "/vault" \
        --argjson ts "$TIMESTAMP" \
        '{
            cli: true,
            vaults: {
                ($vid): {
                    path: $vpath,
                    ts: $ts,
                    open: true,
                    name: $vname
                }
            }
        }' > "$OBSIDIAN_JSON"
    echo "[init-config] Created obsidian.json with vault ID: $VAULT_ID"
fi

# ---- Copy CLAUDE.md to vault root if not present ----
if [ ! -f /vault/CLAUDE.md ]; then
    echo "[init-config] Copying CLAUDE.md to vault root..."
    cp /defaults/CLAUDE.md /vault/CLAUDE.md
else
    echo "[init-config] CLAUDE.md already exists in vault, skipping (preserving user edits)"
fi

# ---- Fix ownership using gosu-friendly approach ----
chown obsidian:obsidian /vault /onedrive-conf
chown obsidian:obsidian /onedrive-conf/* 2>/dev/null || true
chown -R obsidian:obsidian /home/obsidian/.config/obsidian

echo "[init-config] Initialization complete."
