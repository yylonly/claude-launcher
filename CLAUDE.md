# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a single-file bash project: `start-claude.sh` — an interactive launcher for Claude Code that supports multiple API providers.

## Running the Script

```bash
./start-claude.sh
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

- `start-claude.sh`: Main launcher script

## Configuration Files Created

The script creates/modifies these files in `$HOME`:
- `~/.claude-launcher.conf`: Saves last provider/model choices and API keys
- `~/.claude/settings.json`: Claude Code settings (backed up to `~/.claude/settings.json.launcher-bak`)
- `~/.claude.json`: Onboarding status

## Testing

Validate bash syntax with:
```bash
bash -n start-claude.sh
```

## Code Architecture

The script follows a simple structure:
1. **Configuration** (lines 1-30): Shebang, error handling, ANSI colors, path variables
2. **Helper Functions** (lines 28-200): Settings writing, config loading, UI helpers
3. **Claude Code Check** (lines 201-260): Installation check, auto-install, update checking
4. **Main Flow** (lines 265-465): Provider selection → Model selection → Launch
