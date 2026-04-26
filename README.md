# obsctl

Docker container running headless Obsidian CLI + OneDrive sync. Enables Claude Code (and other AI agents) to interact with an Obsidian vault via CLI, with bidirectional OneDrive synchronization.

## Prerequisites

- Docker and Docker Compose
- Obsidian 1.12.4+ (CLI is free for all users since Feb 2026)
- Microsoft OneDrive account

## Quick Start

```bash
# 1. Clone the repository
git clone <repo-url> && cd obsctl

# 2. Create required directories
mkdir -p vault onedrive-conf

# 3. First-time OneDrive authentication (see below)

# 4. Configure environment (auto-detect host UID/GID)
echo "PUID=$(id -u)" > .env
echo "PGID=$(id -g)" >> .env

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
docker compose run --rm --entrypoint "" obsctl \
    gosu obsidian onedrive --confdir=/onedrive-conf --synchronize --single-directory ''

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
| `sync_list` | Which OneDrive folders to sync. Defaults to `/Documents/Obsidian`. |
| `refresh_token` | OAuth refresh token. Auto-created after authentication. |
| `items.sqlite3` | Sync state database. Auto-created by OneDrive client. |

Default `sync_list` syncs only the `/Documents/Obsidian` folder from OneDrive. Edit this file to change which folders are synced.

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

## Using obsctl CLI

Once the container is running, use the `obsctl` CLI wrapper to interact with the vault from the host:

```bash
# Vault info
obsctl vault

# Read a note (by wikilink name — no path prefix needed)
obsctl read "My Note"

# Read a note (by path — auto-prefixes Documents/Obsidian/)
obsctl read sonatus/NSS/foo.md

# Search
obsctl search "keyword"

# List files in a folder
obsctl ls sonatus/NSS

# Create a note
obsctl create name="New Note" content="# Title"

# Move/rename a note
obsctl mv old-path/note.md new-path/note.md

# Show frontmatter properties
obsctl props sonatus/NSS/foo.md

# Set a property
obsctl prop:set name="status" value="done" path=sonatus/NSS/foo.md

# Today's daily note
obsctl today

# Environment health
obsctl status
```

**Path resolution:**
- Argument contains `/` → treated as path, auto-prefixed with `Documents/Obsidian/`
- No `/` → treated as note name (wikilink resolution, no prefix)
- `path=`, `folder=`, `to=` parameters → always auto-prefixed
- `file=`, `name=`, `query=` parameters → never prefixed

**Installation:**
```bash
# Add to PATH (from repo)
ln -s $(pwd)/bin/obsctl ~/.local/bin/obsctl

# Or use directly
./bin/obsctl vault
```

**Configuration (optional):**
Settings are read from `~/.config/obsctl/config.json`:
```json
{
  "vault": "/path/to/vault",
  "vaultPrefix": "Documents/Obsidian",
  "container": "obsctl",
  "user": "obsidian"
}
```

Environment variables override config: `OBS_CONTAINER`, `OBS_VAULT_PREFIX`, `OBS_USER`.

Run `obsctl help` for all available commands.

### CLI Troubleshooting

```bash
# Verify Obsidian process is running
docker exec obsctl ps aux | grep obsidian

# Check CLI socket exists
docker exec obsctl ls -la /home/obsidian/.obsidian-cli.sock

# Re-register CLI binary if needed
docker exec -u obsidian obsctl bash -c \
  'mkdir -p ~/.local/bin && cp /opt/obsidian/obsidian-cli ~/.local/bin/obsidian && chmod +x ~/.local/bin/obsidian'

# Restart Obsidian service
docker exec obsctl /package/admin/s6-2.13.1.0/command/s6-svc -r /run/service/svc-obsidian
```

**Important:** The underlying `docker exec` must use `-u obsidian`. Running as root connects to a different IPC socket and fails. The `obsctl` wrapper handles this automatically.

## Using with Claude Code and Codex

Open Claude Code or Codex in the project directory. Both can use `obsctl` directly:

```bash
obsctl read "My Note"
obsctl search "keyword"
obsctl ls projects/
```

The container also places a `CLAUDE.md` at the vault root with CLI documentation.

### Slash Commands / Prompts

`obsctl` ships strategy-aware skills that wrap the CLI. Install them with:

```bash
obsctl install
```

This deploys:
- `commands/*.md` → `~/.claude/commands/` (Claude Code slash commands)
- `prompts/*.md`  → `~/.codex/prompts/` (Codex CLI prompts)

Currently provides `/vault` — loads the vault strategy (via `obsctl strategy`) and then performs search/read/create according to the strategy's rules. Configure the strategy file path in `~/.config/obsctl/config.json` under `"strategy"`.

## Health Checks

The container includes a health check that verifies:
1. Obsidian CLI is responsive
2. OneDrive monitor process is running
3. Vault directory is accessible

```bash
# Check health status
docker compose ps

# Run healthcheck manually
docker compose exec obsctl /scripts/healthcheck.sh

# View service status (s6)
docker compose exec obsctl s6-rc -a list
```

## Troubleshooting

### OneDrive authentication expired
The refresh_token auto-renews. If it expires:
```bash
docker compose down
docker compose run --rm --entrypoint "" obsctl \
    gosu obsidian onedrive --confdir=/onedrive-conf --synchronize --single-directory ''
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
