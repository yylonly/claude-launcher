#!/usr/bin/env bash
# install.sh — Install claude-launcher to PATH

set -euo pipefail

# Colors
BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

SCRIPT_NAME="start-claude.sh"
INSTALL_NAME="claude-launcher"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${SCRIPT_DIR}/${SCRIPT_NAME}"

# Find the best install directory
find_install_dir() {
    # Check for ~/.local/bin
    if [[ -d "${HOME}/.local/bin" ]] && [[ ":${PATH}:" == *":${HOME}/.local/bin:"* ]]; then
        echo "${HOME}/.local/bin"
        return
    fi

    # Check for ~/bin
    if [[ -d "${HOME}/bin" ]] && [[ ":${PATH}:" == *":${HOME}/bin:"* ]]; then
        echo "${HOME}/bin"
        return
    fi

    # Check for /usr/local/bin (may need sudo)
    if [[ -d "/usr/local/bin" ]] && [[ ":${PATH}:" == *":/usr/local/bin:"* ]]; then
        echo "/usr/local/bin"
        return
    fi

    # Default to ~/.local/bin (create if needed)
    echo "${HOME}/.local/bin"
}

INSTALL_DIR="$(find_install_dir)"
TARGET_FILE="${INSTALL_DIR}/${INSTALL_NAME}"

echo -e "${BOLD}Claude Launcher Installer${RESET}"
echo "========================="
echo ""

# Verify source exists
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo -e "${RED}Error: ${SCRIPT_NAME} not found in ${SCRIPT_DIR}${RESET}"
    exit 1
fi

# Check if we need sudo for the install directory
USE_SUDO=false
if [[ ! -w "$INSTALL_DIR" ]] && [[ ! -w "$(dirname "$INSTALL_DIR")" ]]; then
    USE_SUDO=true
fi

# Create directory if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "${YELLOW}Creating directory: ${INSTALL_DIR}${RESET}"
    if [[ "$USE_SUDO" == true ]]; then
        sudo mkdir -p "$INSTALL_DIR"
    else
        mkdir -p "$INSTALL_DIR"
    fi
fi

echo "Source: ${SOURCE_FILE}"
echo "Target: ${TARGET_FILE}"
echo ""

# Copy the script
echo -n "Installing ${INSTALL_NAME}... "
if [[ "$USE_SUDO" == true ]]; then
    sudo cp "$SOURCE_FILE" "$TARGET_FILE"
    sudo chmod +x "$TARGET_FILE"
else
    cp "$SOURCE_FILE" "$TARGET_FILE"
    chmod +x "$TARGET_FILE"
fi
echo -e "${GREEN}✓ Done${RESET}"

# Verify installation
if command -v "$INSTALL_NAME" &>/dev/null; then
    echo ""
    echo -e "${GREEN}Installation successful!${RESET}"
    echo ""
    echo "You can now run:"
    echo -e "  ${BOLD}${INSTALL_NAME}${RESET}"
    echo ""
    echo "Or with the full name:"
    echo -e "  ${BOLD}start-claude${RESET}"
else
    echo ""
    echo -e "${YELLOW}Warning: ${INSTALL_NAME} not found in PATH${RESET}"
    echo "You may need to restart your shell or add the following to your shell config:"
    echo ""
    echo "  export PATH=\"${INSTALL_DIR}:\${PATH}\""
fi

# Check if we should also create 'start-claude' alias
if [[ ! -f "${INSTALL_DIR}/start-claude" ]]; then
    echo -n "Creating start-claude alias... "
    if [[ "$USE_SUDO" == true ]]; then
        sudo ln -sf "$TARGET_FILE" "${INSTALL_DIR}/start-claude"
    else
        ln -sf "$TARGET_FILE" "${INSTALL_DIR}/start-claude"
    fi
    echo -e "${GREEN}✓ Done${RESET}"
fi

echo ""
echo "To uninstall, run:"
echo -e "  ${BOLD}rm ${TARGET_FILE}${RESET}"
echo -e "  ${BOLD}rm ${INSTALL_DIR}/start-claude${RESET}"
