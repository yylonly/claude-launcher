# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a multi-file bash project for Claude Code launcher that supports multiple API providers.

## Project Structure

```
claude-launcher/
├── start-claude.sh       # Main launcher script (core)
├── install.sh           # Local installation script
├── install-remote.sh    # One-liner remote installation
├── README.md           # Project documentation
└── CLAUDE.md           # This file
```

## Subcommands

All subcommands are integrated into `start-claude.sh`:

```bash
cli uninstall              # Uninstall claude-launcher
cli mcp -l                # List all MCP servers
cli mcp -d <name>         # Delete a specific MCP server
cli mcp -a                # Delete all MCP servers
cli plugin -d <name>      # Forcefully delete a plugin
```

## File Dependencies

### start-claude.sh (Core)
- **External Dependencies:**
  - Claude Code (`claude` command)
  - Python 3 (for JSON merging)
  - curl (for API calls and updates)
  - claude-hud plugin (optional)
- **Configuration Files:**
  - `~/.claude-launcher.conf` — Provider, model, API keys
  - `~/.claude/settings.json` — Claude Code settings
  - `~/.claude.json` — Claude onboarding status
  - `~/.claude/plugins/claude-hud/config.json` — HUD config

### install.sh
- **Source:** `start-claude.sh`
- **Target:** `~/.local/bin/` (or `~/bin`, `/usr/local/bin`)

### install-remote.sh
- **Source:** GitHub Raw URL
- **Target:** `~/.local/bin/`


## Running the Script

```bash
./start-claude.sh           # Quick launch with saved configuration
./start-claude.sh -r        # Resume last session
./start-claude.sh -r [id]   # Resume specific session by ID
./start-claude.sh -c        # Interactive configuration
./start-claude.sh -h        # Show help
```

The script is interactive and will:

1. **Check Claude Code** — Verifies installation, auto-installs if missing, checks for updates
2. **Provider selection** (Anthropic, MiniMaxi, or Bailian/DashScope)
3. **Model selection** (varies by provider)
4. **API keys** (if not already set or saved)

## Providers Supported

- **Anthropic** (option 1): Official Claude models via Anthropic API
- **MiniMaxi** (option 2): MiniMax API with MiniMax models
- **Bailian** (option 3): Alibaba DashScope with Qwen models

## Key Files

- `start-claude.sh`: Main launcher script (interactive Claude Code launcher)
- `install.sh`: Installation script (installs launcher to PATH)
- `install-remote.sh`: Remote installation script

## Configuration Files Created

The script creates/modifies these files in `$HOME`:
- `~/.claude-launcher.conf`: Saves last provider/model choices, API keys, and last project directory
- `~/.claude/settings.json`: Claude Code settings (backed up to `~/.claude/settings.json.launcher-bak`)
- `~/.claude.json`: Onboarding status
- `~/.claude/plugins/claude-hud/config.json`: HUD plugin configuration

## Testing

Validate bash syntax with:

```bash
bash -n start-claude.sh
```

## Version

**Before pushing to git, update version in ALL files:**
- `start-claude.sh` → `VERSION="X.X.X"`
- `README.md` → version number
- `install.sh` → `VERSION` (if exists)
- `install-remote.sh` → `VERSION` (if exists)

## Code Architecture

The script follows a simple structure:
1. **Configuration** (lines 1-39): Shebang, error handling, ANSI colors, path variables
2. **Helper Functions** (lines ~40-760): Settings writing, config loading, UI helpers, plugin/MCP configuration
3. **Claude Code Check** (lines ~312-444): Installation check, auto-install, update checking
4. **Claude-hud Plugin** (lines ~446-554): Plugin check, install and configure
5. **Brave/Tavily MCP** (lines ~556-758): MCP server configuration
6. **Quick Launch & Resume** (lines ~760-1080): Quick launch with saved config, session resume
7. **Main Flow** (lines ~900-1328): Argument handling → Provider selection → Model selection → Launch
