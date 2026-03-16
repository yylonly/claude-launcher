# Claude Launcher

An interactive launcher for [Claude Code](https://claude.ai/code) that supports multiple AI API providers.

## Features

- **Multiple Providers** — Switch between Anthropic, MiniMaxi, and Bailian (DashScope)
- **Easy Configuration** — Save API keys and preferred models
- **Quick Launch** — Start Claude Code with your chosen provider in seconds
- **Session Resume** — Resume last session with -r flag
- **Auto Update** — Check and update launcher with -u flag
- **Simple Install** — One-command install to your PATH
- **Auto-Install** — Automatically installs Claude Code if not present

## Project Structure

```
claude-launcher/
├── start-claude.sh      # Main launcher script (core)
├── install.sh          # Local installation script
├── install-remote.sh   # One-liner remote installation
├── uninstall.sh        # Uninstallation script
├── delete-plugin.sh    # Plugin deletion utility
├── delete-mcp.sh      # MCP server deletion utility
├── README.md           # This file
└── CLAUDE.md           # Claude Code configuration guide
```

## File Dependencies

### start-claude.sh (Core)
- **External Dependencies:**
  - Claude Code (`claude` command)
  - Python 3 (for JSON merging)
  - curl (for API calls and updates)
  - claude-hud plugin (optional, auto-installed)
- **Configuration Files:**
  - `~/.claude-launcher.conf` — Provider, model, API keys, last project directory
  - `~/.claude/settings.json` — Claude Code configuration
  - `~/.claude.json` — Claude Code onboarding status
  - `~/.claude/plugins/claude-hud/config.json` — HUD plugin config

### install.sh
- **Dependencies:**
  - `start-claude.sh` (source file to install)
  - bash shell
- **Creates:**
  - `~/.local/bin/claude-launcher` (or `~/bin`, `/usr/local/bin`)
  - `~/.local/bin/cli` (symlink)
  - `~/.local/bin/start-claude` (symlink)

### install-remote.sh
- **Dependencies:**
  - GitHub Raw URL: `https://raw.githubusercontent.com/yylonly/claude-launcher/main/start-claude.sh`
  - curl (for downloading)
- **Creates:**
  - `~/.local/bin/claude-launcher`
  - `~/.local/bin/cli` (symlink)
  - `~/.local/bin/start-claude` (symlink)

### uninstall.sh
- **Dependencies:**
  - `~/.claude-launcher.conf` (config file)
  - `~/.claude/settings.json.launcher-bak` (backup file)
- **Removes:**
  - `~/.local/bin/claude-launcher`
  - `~/.local/bin/cli`
  - `~/.local/bin/start-claude`
  - Optional: config files

### delete-plugin.sh
- **Dependencies:**
  - `~/.claude/plugins/` (plugin directory)
  - `~/.claude/plugins/installed_plugins.json` (plugin registry)

## Supported Providers

| Provider | Models |
|----------|--------|
| **Anthropic** | Claude Opus 4.6, Sonnet 4.6, Haiku 4.5 |
| **MiniMaxi** | MiniMax-M2.5, M2.5-highspeed, M2.1, M2 |
| **Bailian/DashScope** | Kimi-K2.5, GLM-5, Qwen3-Max, Qwen3-Coder, GLM-4.7, Qwen3-Flash, Qwen-Turbo, Qwen-Long, QwQ-Plus |

## Installation

### One-liner Install (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/yylonly/claude-launcher/main/install-remote.sh | bash
```

### Quick Install

```bash
git clone https://github.com/yylonly/claude-launcher.git
cd claude-launcher
./install.sh
```

This installs `claude-launcher` (and `start-claude` alias) to your PATH.

### Manual Install

Copy `start-claude.sh` to a directory in your PATH:

```bash
cp start-claude.sh ~/.local/bin/claude-launcher
chmod +x ~/.local/bin/claude-launcher
```

## Usage

Run the launcher:

```bash
cli                     # Quick launch with saved config
cli -r                 # Resume last session
cli -r [session_id]    # Resume specific session
cli -c                 # Interactive configuration
cli -u                 # Check for updates
cli -h                 # Show help
# or
claude-launcher
start-claude
```

### First Run

1. **Claude Code Check** — If Claude Code is not installed, the launcher will offer to install it automatically
2. **Update Check** — If already installed, checks for updates and prompts to update if available
3. Select your API provider (1-3)
4. Choose a model
5. Enter your API key (or use saved key)
6. Claude Code launches with your selected configuration

### Session Resume

The launcher saves your last project directory, so you can quickly resume your last session:

```bash
cli -r              # Resume last session (interactive picker)
cli -r [session_id] # Resume a specific session by ID
```

### Auto Update

Check for launcher updates:

```bash
cli -u              # Check for updates and prompt to install
```

### Configuration

Your settings are saved to:
- `~/.claude-launcher.conf` — Provider, model, API keys, and last project directory
- `~/.claude/settings.json` — Claude Code configuration

Original settings are backed up to `~/.claude/settings.json.launcher-bak`

## Uninstallation

```bash
./uninstall.sh
```

This removes the launcher binaries and optionally cleans up configuration files.

## Requirements

- bash 4.0+
- API key for your chosen provider
- [Claude Code](https://claude.ai/code) (auto-installed if missing)

## Getting API Keys

- **Anthropic**: https://console.anthropic.com/
- **MiniMaxi**: https://www.minimaxi.com/
- **Bailian/DashScope**: https://dashscope.aliyun.com/

## License

MIT

## Contributing

Pull requests welcome. Please ensure `bash -n start-claude.sh` passes before submitting.
