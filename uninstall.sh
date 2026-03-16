#!/usr/bin/env bash
# uninstall.sh — Uninstall claude-launcher

set -euo pipefail

# Version
VERSION="1.1.0"

# Colors
BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
RESET='\033[0m'

INSTALL_NAME="claude-launcher"
ALIAS_NAME="start-claude"

# Config and backup files to optionally remove
CONFIG_FILE="${HOME}/.claude-launcher.conf"
CLAUDE_SETTINGS_BAK="${HOME}/.claude/settings.json.launcher-bak"

echo -e "${BOLD}Claude Launcher Uninstaller${RESET}"
echo "============================"
echo ""

# Find installed locations
find_install_dir() {
    if command -v "$INSTALL_NAME" &>/dev/null; then
        dirname "$(command -v "$INSTALL_NAME")"
        return
    fi

    # Check common locations
    for dir in "${HOME}/.local/bin" "${HOME}/bin" "/usr/local/bin"; do
        if [[ -f "${dir}/${INSTALL_NAME}" ]]; then
            echo "$dir"
            return
        fi
    done

    echo ""
}

INSTALL_DIR="$(find_install_dir)"
FOUND_FILES=()

# Check for installed files
if [[ -n "$INSTALL_DIR" && -d "$INSTALL_DIR" ]]; then
    if [[ -f "${INSTALL_DIR}/${INSTALL_NAME}" ]]; then
        FOUND_FILES+=("${INSTALL_DIR}/${INSTALL_NAME}")
    fi
    if [[ -L "${INSTALL_DIR}/${ALIAS_NAME}" ]]; then
        FOUND_FILES+=("${INSTALL_DIR}/${ALIAS_NAME}")
    fi
    if [[ -L "${INSTALL_DIR}/cli" ]]; then
        FOUND_FILES+=("${INSTALL_DIR}/cli")
    fi
fi

# Check for config files
FOUND_CONFIGS=()
[[ -f "$CONFIG_FILE" ]] && FOUND_CONFIGS+=("$CONFIG_FILE")
[[ -f "$CLAUDE_SETTINGS_BAK" ]] && FOUND_CONFIGS+=("$CLAUDE_SETTINGS_BAK")

if [[ ${#FOUND_FILES[@]} -eq 0 && ${#FOUND_CONFIGS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No claude-launcher installation found.${RESET}"
    exit 0
fi

# Show what will be removed
echo "The following files will be removed:"
echo ""

if [[ ${#FOUND_FILES[@]} -gt 0 ]]; then
    echo -e "${CYAN}Installed binaries:${RESET}"
    for f in "${FOUND_FILES[@]}"; do
        echo "  • $f"
    done
    echo ""
fi

if [[ ${#FOUND_CONFIGS[@]} -gt 0 ]]; then
    echo -e "${CYAN}Configuration files:${RESET}"
    for f in "${FOUND_CONFIGS[@]}"; do
        echo "  • $f"
    done
    echo ""
fi

# Ask for confirmation
read -p "Do you want to proceed? [y/N]: " confirm
echo ""

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

# Remove binaries
REMOVED_COUNT=0
for file in "${FOUND_FILES[@]}"; do
    if [[ -f "$file" || -L "$file" ]]; then
        echo -n "Removing ${file}... "
        if [[ -w "$(dirname "$file")" ]]; then
            rm -f "$file"
        else
            sudo rm -f "$file"
        fi
        echo -e "${GREEN}✓ Done${RESET}"
        ((REMOVED_COUNT++)) || true
    fi
done

# Handle config files
if [[ ${#FOUND_CONFIGS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Configuration files found:${RESET}"
    for f in "${FOUND_CONFIGS[@]}"; do
        echo "  • $f"
    done
    echo ""
    read -p "Remove configuration files as well? [y/N]: " remove_config
    echo ""

    if [[ "$remove_config" =~ ^[Yy]$ ]]; then
        for f in "${FOUND_CONFIGS[@]}"; do
            if [[ -f "$f" ]]; then
                echo -n "Removing ${f}... "
                rm -f "$f"
                echo -e "${GREEN}✓ Done${RESET}"
            fi
        done

        # Check if ~/.claude/settings.json was modified by us (has launcher backup)
        CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
        if [[ -f "$CLAUDE_SETTINGS" && -f "${CLAUDE_SETTINGS}.orig" ]]; then
            echo ""
            read -p "Restore original Claude Code settings? [y/N]: " restore_settings
            if [[ "$restore_settings" =~ ^[Yy]$ ]]; then
                mv "${CLAUDE_SETTINGS}.orig" "$CLAUDE_SETTINGS"
                echo -e "${GREEN}Original settings restored.${RESET}"
            fi
        fi
    fi
fi

echo ""
echo -e "${GREEN}Uninstall complete.${RESET}"

# Check if command is still in PATH
if command -v "$INSTALL_NAME" &>/dev/null; then
    echo ""
    echo -e "${YELLOW}Note: Another version of ${INSTALL_NAME} was found in PATH:${RESET}"
    echo "  $(command -v "$INSTALL_NAME")"
fi

echo ""
echo "To reinstall, run:"
echo -e "  ${BOLD}./install.sh${RESET}"
