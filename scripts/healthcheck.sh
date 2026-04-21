#!/bin/bash

# Healthcheck for obsctl container
# Checks: Obsidian CLI responsiveness, OneDrive process, vault accessibility

ERRORS=0

# ---- Check 1: Obsidian process running ----
# Note: obsidian-cli hangs indefinitely in headless Xvfb environments
# (socket connection to Electron never completes), so we check the process instead
if ! pgrep -f "/opt/obsidian/obsidian" >/dev/null 2>&1; then
    echo "UNHEALTHY: Obsidian process not running"
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
