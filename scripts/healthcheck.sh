#!/bin/bash

# Healthcheck for obsctl container
# Checks: Obsidian CLI responsiveness, OneDrive process, vault accessibility

ERRORS=0

# ---- Check 1: Obsidian CLI readiness ----
# Try obsidian vault first (confirms CLI + vault registration)
# Fall back to obsidian help (confirms CLI binary works)
if gosu obsidian /opt/obsidian/obsidian --no-sandbox vault >/dev/null 2>&1; then
    : # CLI responsive with vault command
elif gosu obsidian /opt/obsidian/obsidian --no-sandbox help >/dev/null 2>&1; then
    : # CLI binary works but vault command may not exist
else
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
