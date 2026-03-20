#!/usr/bin/env bash
# One-liner install script for claude-launcher
# Usage: curl -sSL https://raw.githubusercontent.com/yylonly/claude-launcher/main/install.sh | bash

set -euo pipefail

# Version
VERSION="1.2.2"

INSTALL_NAME="claude-launcher"
INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_URL="https://raw.githubusercontent.com/yylonly/claude-launcher/main/start-claude.sh"

# Colors
BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

echo -e "${BOLD}Claude Launcher Installer (One-liner)${RESET}"
echo "====================================="
echo ""

# Check if directory exists and is writable
if [[ ! -d "$INSTALL_DIR" ]]; then
    mkdir -p "$INSTALL_DIR"
fi

if [[ ! -w "$INSTALL_DIR" ]]; then
    echo -e "${RED}Error: Cannot write to ${INSTALL_DIR}${RESET}"
    exit 1
fi

# Download and install
echo -n "Downloading start-claude.sh... "
if curl -sSL "$SCRIPT_URL" -o "${INSTALL_DIR}/${INSTALL_NAME}"; then
    chmod +x "${INSTALL_DIR}/${INSTALL_NAME}"
    echo -e "${GREEN}✓${RESET}"
else
    echo -e "${RED}Failed${RESET}"
    exit 1
fi

# Create symlinks
echo -n "Creating cli symlink... "
ln -sf "${INSTALL_DIR}/${INSTALL_NAME}" "${INSTALL_DIR}/cli" 2>/dev/null || true
echo -e "${GREEN}✓${RESET}"

echo -n "Creating start-claude symlink... "
ln -sf "${INSTALL_DIR}/${INSTALL_NAME}" "${INSTALL_DIR}/start-claude" 2>/dev/null || true
echo -e "${GREEN}✓${RESET}"

# Ensure in PATH
if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
    echo ""
    echo -e "${YELLOW}Note: Add to PATH if not already:${RESET}"
    echo "  export PATH=\"${INSTALL_DIR}:\${PATH}\""
    echo ""
fi

echo -e "${GREEN}Installation complete!${RESET}"
echo ""
echo "Run:"
echo -e "  ${BOLD}cli${RESET}    — Launch with saved config"
echo -e "  ${BOLD}cli -r${RESET}  — Resume last session"
echo -e "  ${BOLD}cli -c${RESET}  — Interactive configuration"
echo -e "  ${BOLD}cli -u${RESET}  — Check for updates"
echo -e "  ${BOLD}cli -h${RESET}  — Show help"
