#!/bin/bash
#
# delete-plugin.sh - Forcefully remove a Claude plugin
#
# Usage: ./delete-plugin.sh <plugin-name>
# Example: ./delete-plugin.sh claude-hud
#

set -e

# Version
VERSION="1.2.2"

PLUGIN_DIR="$HOME/.claude/plugins"
CONFIG_FILE="$PLUGIN_DIR/installed_plugins.json"
CACHE_DIR="$PLUGIN_DIR/cache"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    echo -e "${BLUE}delete-plugin.sh${NC} - Forcefully remove a Claude plugin"
    echo ""
    echo "Usage:"
    echo "  $0 <plugin-name>    Remove a plugin"
    echo "  $0 --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 claude-hud"
    echo "  $0 code-simplifier"
    echo "  $0 claude-hud@claude-hud"
    echo ""
    echo "Note: Use this script when 'claude plugin remove' fails due to bugs."
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <plugin-name>${NC}"
    echo "Example: $0 claude-hud"
    echo "Run '$0 --help' for more information."
    exit 1
fi

PLUGIN_NAME="$1"

# Handle both formats: "claude-hud" and "claude-hud@claude-hud"
PLUGIN_KEY=$(echo "$PLUGIN_NAME" | sed 's/@.*$//')
if [[ "$PLUGIN_NAME" == *"@"* ]]; then
    PLUGIN_FULL="$PLUGIN_NAME"
else
    PLUGIN_FULL="$PLUGIN_NAME@$PLUGIN_NAME"
fi

echo -e "${YELLOW}Forcefully removing plugin: $PLUGIN_NAME${NC}"

# Find and remove plugin directory
PLUGIN_PATH=""
if [ -d "$PLUGIN_DIR/$PLUGIN_NAME" ]; then
    PLUGIN_PATH="$PLUGIN_DIR/$PLUGIN_NAME"
elif [ -d "$PLUGIN_DIR/${PLUGIN_FULL}" ]; then
    PLUGIN_PATH="$PLUGIN_DIR/${PLUGIN_FULL}"
fi

if [ -n "$PLUGIN_PATH" ]; then
    echo "Removing plugin directory: $PLUGIN_PATH"
    rm -rf "$PLUGIN_PATH"
    echo -e "${GREEN}✓ Directory removed${NC}"
else
    echo -e "${YELLOW}⚠ Plugin directory not found${NC}"
fi

# Remove from cache
CACHE_PATH=""
if [ -d "$CACHE_DIR" ]; then
    for dir in "$CACHE_DIR"/*; do
        if [ -d "$dir/$PLUGIN_NAME" ] || [ -d "$dir/${PLUGIN_FULL}" ]; then
            CACHE_PATH="$dir/$PLUGIN_NAME"
            [ -d "$dir/${PLUGIN_FULL}" ] && CACHE_PATH="$dir/${PLUGIN_FULL}"
            echo "Removing from cache: $CACHE_PATH"
            rm -rf "$CACHE_PATH"
            echo -e "${GREEN}✓ Cache removed${NC}"
            break
        fi
    done
fi

# Update config file
if [ -f "$CONFIG_FILE" ]; then
    if grep -q "\"$PLUGIN_FULL\"" "$CONFIG_FILE"; then
        echo "Updating $CONFIG_FILE..."
        # Use Python for reliable JSON manipulation
        python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    data = json.load(f)
if '$PLUGIN_FULL' in data.get('plugins', {}):
    del data['plugins']['$PLUGIN_FULL']
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print('✓ Config updated')
else:
    print('⚠ Plugin not found in config')
"
    else
        echo -e "${YELLOW}⚠ Plugin not found in config file${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Config file not found${NC}"
fi

# Update settings.json
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    echo "Updating $SETTINGS_FILE..."
    python3 -c "
import json

with open('$SETTINGS_FILE', 'r') as f:
    data = json.load(f)

modified = False

# Remove from enabledPlugins
if 'enabledPlugins' in data:
    plugins_to_remove = ['$PLUGIN_NAME', '$PLUGIN_KEY', '$PLUGIN_FULL']
    for p in plugins_to_remove:
        if p in data['enabledPlugins']:
            del data['enabledPlugins'][p]
            modified = True
            print(f'✓ Removed from enabledPlugins: {p}')

# Remove from extraKnownMarketplaces
if 'extraKnownMarketplaces' in data:
    marketplaces_to_remove = ['$PLUGIN_NAME', '$PLUGIN_KEY']
    for m in marketplaces_to_remove:
        if m in data['extraKnownMarketplaces']:
            del data['extraKnownMarketplaces'][m]
            modified = True
            print(f'✓ Removed from extraKnownMarketplaces: {m}')

# Check if statusLine references the plugin
if 'statusLine' in data and 'command' in data['statusLine']:
    status_cmd = data['statusLine']['command']
    if '$PLUGIN_NAME' in status_cmd or '$PLUGIN_KEY' in status_cmd:
        del data['statusLine']
        modified = True
        print('✓ Removed statusLine (plugin reference found)')

if modified:
    with open('$SETTINGS_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print('✓ settings.json updated')
else:
    print('⚠ No changes needed in settings.json')
"
else
    echo -e "${YELLOW}⚠ settings.json not found${NC}"
fi

echo -e "${GREEN}Plugin '$PLUGIN_NAME' has been forcefully removed${NC}"
