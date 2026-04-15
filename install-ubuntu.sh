#!/usr/bin/env bash
# install-ubuntu.sh — Install Claude Launcher on Ubuntu/Debian/Linux
# This script installs start-claude-ubuntu.sh to PATH

set -euo pipefail

VERSION="1.2.7"

echo "  Claude Launcher Installer (Ubuntu/Linux)"
echo "  ======================================="
echo ""

# Detect installation directory
if [[ -d "$HOME/.local/bin" && -w "$HOME/.local/bin" ]]; then
    INSTALL_DIR="$HOME/.local/bin"
elif [[ -w "$HOME/bin" ]] || mkdir -p "$HOME/bin" 2>/dev/null; then
    INSTALL_DIR="$HOME/bin"
elif [[ -w "/usr/local/bin" ]]; then
    INSTALL_DIR="/usr/local/bin"
else
    echo "Error: Cannot find writable installation directory."
    echo "Please ensure ~/.local/bin exists and is writable, or ~/bin exists."
    exit 1
fi

echo "  Install directory: $INSTALL_DIR"

# Find the script source
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SOURCE="$SCRIPT_DIR/start-claude-ubuntu.sh"

if [[ ! -f "$SCRIPT_SOURCE" ]]; then
    echo "Error: start-claude-ubuntu.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Check for sudo if installing to system directory
if [[ "$INSTALL_DIR" == "/usr/local/bin" && ! -w "$INSTALL_DIR" ]]; then
    echo "  Note: Writing to /usr/local/bin requires sudo"
fi

# Install the main script
echo ""
echo "  Installing start-claude-ubuntu.sh..."
install -m 755 "$SCRIPT_SOURCE" "$INSTALL_DIR/start-claude-ubuntu.sh" 2>/dev/null || sudo install -m 755 "$SCRIPT_SOURCE" "$INSTALL_DIR/start-claude-ubuntu.sh"

# Create symlinks for different invocation styles
echo "  Creating symlinks..."

# Main launcher as 'cli'
if [[ ! -L "$INSTALL_DIR/cli" ]]; then
    ln -sf "$INSTALL_DIR/start-claude-ubuntu.sh" "$INSTALL_DIR/cli"
fi

# Main launcher as 'start-claude' (for backwards compatibility)
if [[ ! -L "$INSTALL_DIR/start-claude" ]]; then
    ln -sf "$INSTALL_DIR/start-claude-ubuntu.sh" "$INSTALL_DIR/start-claude"
fi

# Ensure ~/.local/bin is in PATH
SHELL_RC="$HOME/.bashrc"
if ! grep -q '~/.local/bin' "$SHELL_RC" 2>/dev/null; then
    echo ""
    echo "  Adding ~/.local/bin to PATH in $SHELL_RC..."
    echo '' >> "$SHELL_RC"
    echo '# Claude Launcher' >> "$SHELL_RC"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
fi

# Install Claude Code if not present
if ! command -v claude &>/dev/null; then
    echo ""
    echo "  Claude Code is not installed."
    read -rp "  Install Claude Code now? [Y/n]: " install_claude
    if [[ -z "$install_claude" || "$install_claude" =~ ^[Yy]$ ]]; then
        echo ""
        echo "  Running Claude Code installer..."
        curl -sSL https://claude.ai/install.sh | bash
    fi
fi

echo ""
echo "  ======================================="
echo "  Installation complete!"
echo ""
echo "  Add to PATH (if not already):"
echo "    source $SHELL_RC"
echo ""
echo "  Usage:"
echo "    cli                # Quick launch"
echo "    cli -c             # Configure"
echo "    cli -r             # Resume session"
echo "    cli -h             # Show help"
echo ""
echo "  Version: $VERSION"
echo ""
