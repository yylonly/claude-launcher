#!/usr/bin/env zsh
# export-iterm.sh — Export current iTerm2 configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.xml"

echo "Exporting iTerm2 configuration..."

# Export from plist to XML format
plutil -convert xml1 ~/Library/Preferences/com.googlecode.iterm2.plist -o "$CONFIG_FILE"

if [[ -f "$CONFIG_FILE" ]]; then
    echo "✓ Configuration exported to: $CONFIG_FILE"
    echo ""
    echo "To import on another machine:"
    echo "  1. Copy this directory to the new machine"
    echo "  2. Run: ./install.sh"
else
    echo "✗ Failed to export configuration"
    exit 1
fi
