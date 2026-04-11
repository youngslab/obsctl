# obsidian-sync

Docker container running headless Obsidian CLI + OneDrive sync. Enables Claude Code (and other AI agents) to interact with an Obsidian vault via CLI, with bidirectional OneDrive synchronization.

## Prerequisites

- Docker and Docker Compose
- Obsidian 1.12.4+ (CLI is free for all users since Feb 2026)
- Microsoft OneDrive account

## Quick Start

```bash
# 1. Clone the repository
git clone <repo-url> && cd obsidian-sync

# 2. Create required directories
mkdir -p vault onedrive-conf

# 3. First-time OneDrive authentication (see below)

# 4. Configure environment (auto-detect host UID/GID)
echo "PUID=$(id -u)" > .env
echo "PGID=$(id -g)" >> .env
echo "VAULT_NAME=MyVault" >> .env

# 5. Build and start
docker compose up -d

# 6. Verify
docker compose ps       # Should show "healthy"
docker compose logs -f  # Watch startup logs
```

## First-Time OneDrive Authentication

You must authenticate with OneDrive before the container can sync. Choose one option:

### Option A: Interactive Authentication (Recommended)

```bash
# Build the image first
docker compose build

# Run OneDrive auth interactively
docker compose run --rm obsidian-sync \
    onedrive --confdir=/onedrive-conf --auth-uri

# 1. Copy the URL printed to the terminal
# 2. Open it in your browser
# 3. Sign in with your Microsoft account
# 4. Copy the redirect URI back into the terminal
# 5. The refresh_token is saved to ./onedrive-conf/refresh_token
```

### Option B: Auth Response Environment Variable

If you already have an auth response URI:

```bash
# Set in .env file
ONEDRIVE_AUTHRESPONSE=https://login.microsoftonline.com/...

# Start the container
docker compose up -d
```

After authentication, the `refresh_token` file is automatically saved and reused on subsequent starts.

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID for the obsidian user |
| `PGID` | `1000` | Group ID for the obsidian group |
| `VAULT_NAME` | `MyVault` | Name for the Obsidian vault |
| `ONEDRIVE_AUTHRESPONSE` | _(empty)_ | OneDrive auth URI (first-time only) |

### Volume Mounts

| Container Path | Host Path | Purpose |
|----------------|-----------|---------|
| `/vault` | `./vault` | Obsidian vault data (bidirectional sync with OneDrive) |
| `/onedrive-conf` | `./onedrive-conf` | OneDrive credentials, config, sync state |
| `/home/obsidian/.config/obsidian` | Named volume | Obsidian application state |

### OneDrive Configuration Files

Located in `./onedrive-conf/`:

| File | Purpose |
|------|---------|
| `config` | Sync settings (monitor interval, skip patterns). Auto-created with defaults if missing. |
| `sync_list` | Which OneDrive folders to sync. Defaults to `/Obsidian/`. |
| `refresh_token` | OAuth refresh token. Auto-created after authentication. |
| `items.sqlite3` | Sync state database. Auto-created by OneDrive client. |

Default `sync_list` syncs only the `/Obsidian/` folder from OneDrive. Edit this file to change which folders are synced.

Default `config` sets `monitor_interval = 600` (10 minutes) to reduce API calls and mitigate file conflicts.

## Architecture

```
┌─────────────────────────────────────────────┐
│           Docker Container (s6-overlay)      │
│                                              │
│  ┌──────────┐  init-config (oneshot)         │
│  │entrypoint│──→ PUID/PGID setup             │
│  │   .sh    │──→ obsidian.json generation    │
│  │          │──→ config defaults             │
│  └──────────┘──→ CLAUDE.md seeding           │
│                                              │
│  ┌──────────┐  svc-xvfb (longrun)           │
│  │  Xvfb    │  Virtual display :99           │
│  └────┬─────┘                                │
│       │ depends                              │
│  ┌────▼─────┐  svc-obsidian (longrun)       │
│  │ Obsidian │  Electron app (headless)       │
│  │   CLI    │  --no-sandbox --disable-gpu    │
│  └──────────┘                                │
│                                              │
│  ┌──────────┐  svc-onedrive (longrun)       │
│  │ OneDrive │  --monitor mode                │
│  │  Client  │  Bidirectional sync            │
│  └──────────┘                                │
│       │                    │                 │
│  /onedrive-conf        /vault               │
│  (credentials)    (Obsidian vault)           │
└───────┼────────────────────┼─────────────────┘
        │                    │
   Host volume          Host volume
   (./onedrive-conf)    (./vault)
                             │
                        OneDrive ☁️
```

**Service Dependency Chain:**
- `init-config` runs first (oneshot)
- `svc-xvfb` starts after init-config
- `svc-obsidian` starts after svc-xvfb (needs display)
- `svc-onedrive` starts after init-config (independent of Obsidian)

## Using with Claude Code

The container automatically places a `CLAUDE.md` at the vault root on first start. This file teaches Claude Code instances how to use the `obsidian` CLI to search, read, create, and modify notes.

To use:
1. Point Claude Code at the vault directory
2. Claude reads `CLAUDE.md` and understands available CLI commands
3. Claude can search, read, create, and modify notes via the CLI

## Health Checks

The container includes a health check that verifies:
1. Obsidian CLI is responsive
2. OneDrive monitor process is running
3. Vault directory is accessible

```bash
# Check health status
docker compose ps

# Run healthcheck manually
docker compose exec obsidian-sync /scripts/healthcheck.sh

# View service status (s6)
docker compose exec obsidian-sync s6-rc -a list
```

## Troubleshooting

### OneDrive authentication expired
The refresh_token auto-renews. If it expires:
```bash
docker compose down
docker compose run --rm obsidian-sync onedrive --confdir=/onedrive-conf --auth-uri
docker compose up -d
```

### Obsidian not starting
Check logs for Xvfb or Obsidian errors:
```bash
docker compose logs | grep -E "xvfb|obsidian"
```

### Sync conflicts
OneDrive creates `.conflict` files when both local and remote change. Resolve manually:
```bash
find ./vault -name "*.conflict" -type f
```

### High CPU usage
Xvfb + Electron can consume resources. Consider increasing `monitor_interval` in `onedrive-conf/config` to reduce sync frequency.

### Permission issues
Ensure PUID/PGID in `.env` match your host user:
```bash
echo "PUID=$(id -u)" >> .env
echo "PGID=$(id -g)" >> .env
```

## Security Notes

- **Never commit** `onedrive-conf/` to git (contains OAuth tokens)
- The `.gitignore` excludes `onedrive-conf/`, `vault/`, and `.env` by default
- The container runs as a non-root user (configurable via PUID/PGID)
- No ports are exposed (CLI-only, no web interface)
- Image size is ~2GB+ due to Electron runtime

## License

This project provides Docker configuration for running Obsidian and the OneDrive Linux client. Obsidian CLI is free for all users since v1.12.4. OneDrive client is [GPL-3.0](https://github.com/abraunegg/onedrive/blob/master/LICENSE).
