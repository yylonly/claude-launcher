#!/usr/bin/env zsh
# install-iterm.sh — Install iTerm2 and import configuration

set -euo pipefail

# Colors
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.xml"

echo -e "${BOLD}iTerm2 Installer${RESET}"
echo "=================="
echo ""

# Check if iTerm2 is installed
if [[ -d "/Applications/iTerm.app" ]]; then
    echo -e "${GREEN}✓${RESET} iTerm2 is already installed"
else
    echo -e "${YELLOW}iTerm2 is not installed.${RESET}"
    echo ""
    print -n "  Download and install iTerm2? [Y/n]: " >&2
    read install_choice
    echo ""

    if [[ -z "$install_choice" || "$install_choice" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Installing iTerm2 via Homebrew...${RESET}"
        if command -v brew &> /dev/null; then
            if brew install --cask iterm2 2>&1; then
                echo -e "${GREEN}✓ iTerm2 installed successfully!${RESET}"
            else
                echo -e "${RED}Failed to install iTerm2 via Homebrew${RESET}"
                exit 1
            fi
        else
            echo -e "${RED}Homebrew is not installed. Please install Homebrew first.${RESET}"
            echo "  Visit: https://brew.sh"
            exit 1
        fi
    else
        echo "Installation cancelled."
        exit 0
    fi
fi

# Install SF Mono font
echo ""
echo -e "${CYAN}Installing SF Mono font...${RESET}"
FONT_DIR="${HOME}/Library/Fonts"
mkdir -p "$FONT_DIR"

# Check if SF Mono is already installed
if fc-list | grep -qi "sf mono"; then
    echo -e "${GREEN}✓${RESET} SF Mono font is already installed"
else
    echo "  Downloading SF Mono font..."
    local tmp_zip=$(mktemp).zip
    local font_url="https://developer.apple.com/design/downloads/SF-Mono.dmg"

    if curl -sSL "$font_url" -o "$tmp_zip"; then
        # Mount the DMG
        local mount_point=$(mktemp -d)
        hdiutil attach "$tmp_zip" -mountpoint "$mount_point" -nobrowse 2>/dev/null || {
            echo -e "${YELLOW}Warning: Could not mount DMG, trying alternative method${RESET}"
            rm -f "$tmp_zip"
            # Try to install Monaco as fallback
            if [[ -f "/System/Library/Fonts/Monaco.ttf" ]]; then
                cp "/System/Library/Fonts/Monaco.ttf" "$FONT_DIR/" 2>/dev/null && echo -e "${GREEN}✓${RESET} Monaco font installed"
            fi
            exit 0
        }

        # Find the pkg file in the DMG and extract fonts
        local pkg_file=$(find "$mount_point" -name "*.pkg" 2>/dev/null | head -1)
        if [[ -n "$pkg_file" ]]; then
            # Extract package using xar
            local pkg_extracted="/tmp/sfmono_extract_$$"
            rm -rf "$pkg_extracted" 2>/dev/null
            mkdir -p "$pkg_extracted"
            xar -xf "$pkg_file" -C "$pkg_extracted" 2>/dev/null

            # Find and extract fonts from Payload (gzip compressed cpio)
            local payload_file="$pkg_extracted"/SFMonoFonts.pkg/Payload
            if [[ -f "$payload_file" ]]; then
                local fonts_dir="$pkg_extracted"/fonts_out
                rm -rf "$fonts_dir" 2>/dev/null
                mkdir -p "$fonts_dir"
                (cd "$fonts_dir" && gzip -dc "$payload_file" | cpio -id 2>/dev/null)

                # Copy extracted fonts
                find "$fonts_dir" -name "*.ttf" -o -name "*.otf" 2>/dev/null | while read -r font; do
                    cp "$font" "$FONT_DIR/" 2>/dev/null && echo "  Installed: $(basename "$font")"
                done
                rm -rf "$fonts_dir"
            fi
            rm -rf "$pkg_extracted"
        else
            # Fallback: copy any direct font files
            find "$mount_point" -name "*.ttf" -o -name "*.otf" 2>/dev/null | while read -r font; do
                cp "$font" "$FONT_DIR/" 2>/dev/null && echo "  Installed: $(basename "$font")"
            done
        fi

        hdiutil detach "$mount_point" 2>/dev/null || true
        rm -f "$tmp_zip"
        echo -e "${GREEN}✓ SF Mono font installed${RESET}"
    else
        echo -e "${YELLOW}Warning: Could not download SF Mono font${RESET}"
        echo "  You can manually install from: https://developer.apple.com/fonts/"
    fi
fi

# Import iTerm2 configuration
echo ""
if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${CYAN}Importing iTerm2 configuration...${RESET}"

    local pref_file="${HOME}/Library/Preferences/com.googlecode.iterm2.plist"

    # Backup existing preferences
    if [[ -f "$pref_file" ]]; then
        cp "$pref_file" "${pref_file}.backup-$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
        echo -e "  ${DIM}Backed up existing preferences${RESET}"
    fi

    # Import the configuration using plutil
    if plutil -replace "New Bookmarks" -xml "$(plutil -convert xml1 -stdout "$CONFIG_FILE" 2>/dev/null | plutil -extract "New Bookmarks" -xml -stdout - 2>/dev/null)" "$pref_file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} iTerm2 configuration imported"
    elif plutil -convert xml1 -stdout "$CONFIG_FILE" 2>/dev/null | defaults import com.googlecode.iterm2 - 2>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} iTerm2 configuration imported"
    else
        # Fallback: copy the file directly
        cp "$CONFIG_FILE" "$pref_file" 2>/dev/null && echo -e "  ${GREEN}✓${RESET} iTerm2 configuration copied"
    fi

    echo ""
    echo -e "${DIM}Please restart iTerm2 for changes to take effect.${RESET}"
else
    echo -e "${YELLOW}⚠ No configuration file found: ${CONFIG_FILE}${RESET}"
    echo -e "${DIM}Run export.sh on the source machine first.${RESET}"
fi

echo ""
echo -e "${GREEN}✓ Setup complete!${RESET}"
