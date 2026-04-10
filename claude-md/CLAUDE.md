# Obsidian Vault - Claude Code Guide

## Overview

This vault is managed by Obsidian and synced via OneDrive. You can interact with it using the `obsidian` CLI command. Changes sync to OneDrive automatically with a ~10 minute polling interval.

**Important:** The `obsidian` CLI communicates with a running Obsidian process via IPC. All commands must be run inside the container where Obsidian is running.

## CLI Usage

All commands follow this pattern:
```bash
obsidian --no-sandbox <command> [arguments...]
```

**Note:** The `--no-sandbox` flag is required in this Docker container environment.

Run `obsidian --no-sandbox help` for the complete list of available commands.

## Core Commands

### Search
```bash
# Full-text search across the vault
obsidian search query="meeting notes" limit=10

# Search with context lines
obsidian search:context query="project deadline"
```

### Read & Write
```bash
# Read a note
obsidian read path="folder/note.md"

# Create a new note
obsidian create name="New Note" content="# My New Note\n\nContent here."

# Append to an existing note
obsidian append path="folder/note.md" content="\n\n## New Section\nAdded content."

# Prepend to a note
obsidian prepend path="folder/note.md" content="**Updated:** 2026-04-07\n\n"

# Delete a note
obsidian delete path="folder/note.md"

# Move/rename a note
obsidian move path="old-location/note.md" to="new-location/note.md"
```

### Browse Vault
```bash
# List all files (optionally in a folder)
obsidian files folder="Journal/"

# List all folders
obsidian folders

# Get file info
obsidian file path="folder/note.md"

# Get vault info
obsidian vault
```

### Daily Notes
```bash
# Read today's daily note
obsidian daily:read

# Append to today's daily note
obsidian daily:append content="- [ ] New task for today"

# Prepend to today's daily note
obsidian daily:prepend content="## Morning Review\n"

# Get today's daily note path
obsidian daily:path
```

### Properties (Frontmatter)
```bash
# List all properties of a note
obsidian properties path="note.md"

# Read a specific property
obsidian property:read name="tags" path="note.md"

# Set a property
obsidian property:set name="status" value="done" path="note.md"

# Remove a property
obsidian property:remove name="draft" path="note.md"
```

### Tags
```bash
# List all tags with counts
obsidian tags counts sort=count
```

### Links & Structure
```bash
# List incoming links (backlinks) to a note
obsidian backlinks file="Note Title"

# List outgoing links from a note
obsidian links file="Note Title"

# Find orphan notes (no incoming links)
obsidian orphans

# Find dead-end notes (no outgoing links)
obsidian deadends

# Find unresolved links
obsidian unresolved
```

### Tasks
```bash
# List incomplete tasks
obsidian tasks todo

# List completed tasks
obsidian tasks done

# Toggle a specific task
obsidian task path="note.md" line=5 toggle
```

### Templates
```bash
# List available templates
obsidian templates

# Insert a template into a note
obsidian template:insert name="meeting-template" path="note.md"
```

### Outline
```bash
# Get heading outline of a file
obsidian outline path="note.md"
```

## Common Workflows

### Find and update a note
```bash
# 1. Search for the note
obsidian search query="quarterly review"

# 2. Read the note
obsidian read path="Work/quarterly-review-q1.md"

# 3. Append updates
obsidian append path="Work/quarterly-review-q1.md" content="\n\n## Q2 Updates\n- Item 1\n- Item 2"
```

### Create a daily log entry
```bash
# Append a timestamped entry to today's daily note
obsidian daily:append content="\n### $(date +%H:%M) - Meeting Notes\n- Discussed project timeline\n- Action items assigned"
```

### Organize notes with tags and properties
```bash
# Set status property
obsidian property:set name="status" value="in-progress" path="Projects/feature-x.md"

# Find all notes with a specific tag
obsidian search query="tag:#project/active"
```

### Explore vault structure
```bash
# Get overview
obsidian vault

# Browse folders
obsidian folders

# List files in a specific area
obsidian files folder="Projects/"

# Check for orphan notes that need linking
obsidian orphans
```

## Sync Awareness

- **Sync interval:** Changes sync to OneDrive every ~10 minutes (configurable via `monitor_interval`)
- **Avoid rapid writes:** Don't make many successive writes to the same file in quick succession. Allow time for sync.
- **Conflict files:** OneDrive creates `.conflict` files on sync conflicts. These need manual resolution.
- **After writing:** Allow sync time before expecting changes to appear on other devices.

## Limitations

- The `obsidian` CLI requires a running Obsidian Electron process (headless via Xvfb in this container)
- Commands are IPC-based; there is no concurrent write safety for the same file
- Some commands may require the vault to be fully indexed first (initial startup may take time)
- The CLI requires an Obsidian Catalyst license ($25 one-time)

## Command Verification Note

> The commands documented above are based on the official Obsidian CLI reference.
> If a command doesn't work as expected, run `obsidian help` to see the actual
> available commands in this container's Obsidian version.
