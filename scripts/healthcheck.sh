#!/bin/bash

# Healthcheck for obsctl container
# Checks: Obsidian CLI responsiveness, OneDrive process, vault accessibility

ERRORS=0

# ---- Check 1: Obsidian CLI readiness ----
# Uses native obsidian-cli (talks via socket to running Electron instance)
if ! gosu obsidian /opt/obsidian/obsidian-cli vault >/dev/null 2>&1; then
    echo "UNHEALTHY: Obsidian CLI not responding"
    ERRORS=$((ERRORS + 1))
fi

# ---- Check 2: OneDrive process running ----
if ! pgrep -f "onedrive.*--monitor" >/dev/null 2>&1; then
    echo "UNHEALTHY: OneDrive monitor not running"
    ERRORS=$((ERRORS + 1))
fi

# ---- Check 3: Vault directory accessible ----
if [ ! -d /vault ]; then
    echo "UNHEALTHY: /vault directory not found"
    ERRORS=$((ERRORS + 1))
fi

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi

exit 0
