# Claude Launcher

An interactive launcher for [Claude Code](https://claude.ai/code) that supports multiple AI API providers.

## Features

- **Multiple Providers** — Switch between Anthropic, MiniMaxi, and Bailian (DashScope)
- **Easy Configuration** — Save API keys and preferred models
- **Quick Launch** — Start Claude Code with your chosen provider in seconds
- **Simple Install** — One-command install to your PATH

## Supported Providers

| Provider | Models |
|----------|--------|
| **Anthropic** | Claude 3 Opus, Sonnet, Haiku |
| **MiniMaxi** | MiniMax-Text-01 |
| **Bailian/DashScope** | Qwen-Max, Qwen-Coder, Qwen-Plus |

## Installation

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
claude-launcher
# or
start-claude
```

### First Run

1. Select your API provider (1-3)
2. Choose a model
3. Enter your API key (or use saved key)
4. Claude Code launches with your selected configuration

### Configuration

Your settings are saved to:
- `~/.claude-launcher.conf` — Provider, model, and API keys
- `~/.claude/settings.json` — Claude Code configuration

Original settings are backed up to `~/.claude/settings.json.launcher-bak`

## Uninstallation

```bash
./uninstall.sh
```

This removes the launcher binaries and optionally cleans up configuration files.

## Requirements

- [Claude Code](https://claude.ai/code) installed
- bash 4.0+
- API key for your chosen provider

## Getting API Keys

- **Anthropic**: https://console.anthropic.com/
- **MiniMaxi**: https://www.minimaxi.com/
- **Bailian/DashScope**: https://dashscope.aliyun.com/

## License

MIT

## Contributing

Pull requests welcome. Please ensure `bash -n start-claude.sh` passes before submitting.
