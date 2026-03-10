#!/usr/bin/env bash
# start-claude.sh — Interactive launcher for Claude Code
# Supports Anthropic, MiniMaxi, and Bailian (DashScope) providers

set -euo pipefail

# ─── Clear any leftover provider env vars from previous sessions ─────────────
unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY

# ─── ANSI colors ────────────────────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
RED='\033[31m'
RESET='\033[0m'

# ─── Paths ───────────────────────────────────────────────────────────────────
CONFIG_FILE="${HOME}/.claude-launcher.conf"
CLAUDE_SETTINGS="${HOME}/.claude/settings.json"
CLAUDE_SETTINGS_BAK="${HOME}/.claude/settings.json.launcher-bak"
CLAUDE_JSON="${HOME}/.claude.json"

# ─── settings.json helpers ───────────────────────────────────────────────────
write_minimax_settings() {
  local api_key="$1"
  local model="$2"
  mkdir -p "${HOME}/.claude"
  # Backup original settings once
  if [[ -f "$CLAUDE_SETTINGS" && ! -f "$CLAUDE_SETTINGS_BAK" ]]; then
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS_BAK"
  fi
  # Escape backslashes and quotes in api_key for JSON
  local escaped_key
  escaped_key="${api_key//\\/\\\\}"
  escaped_key="${escaped_key//\"/\\\"}"
  cat > "$CLAUDE_SETTINGS" <<EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.minimaxi.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "${escaped_key}",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "ANTHROPIC_MODEL": "${model}",
    "ANTHROPIC_SMALL_FAST_MODEL": "${model}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${model}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${model}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${model}"
  },
  "skipDangerousModePermissionPrompt": true
}
EOF
  chmod 600 "$CLAUDE_SETTINGS"
}

restore_settings() {
  if [[ -f "$CLAUDE_SETTINGS_BAK" ]]; then
    cp "$CLAUDE_SETTINGS_BAK" "$CLAUDE_SETTINGS"
  else
    rm -f "$CLAUDE_SETTINGS"
  fi
}

write_bailian_settings() {
  local api_key="$1"
  local model="$2"
  mkdir -p "${HOME}/.claude"
  # Backup original settings once
  if [[ -f "$CLAUDE_SETTINGS" && ! -f "$CLAUDE_SETTINGS_BAK" ]]; then
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS_BAK"
  fi
  # Escape backslashes and quotes in api_key for JSON
  local escaped_key
  escaped_key="${api_key//\\/\\\\}"
  escaped_key="${escaped_key//\"/\\\"}"
  cat > "$CLAUDE_SETTINGS" <<EOF
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://coding.dashscope.aliyuncs.com/apps/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "${escaped_key}",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "ANTHROPIC_MODEL": "${model}",
    "ANTHROPIC_SMALL_FAST_MODEL": "${model}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${model}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${model}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${model}"
  },
  "skipDangerousModePermissionPrompt": true
}
EOF
  chmod 600 "$CLAUDE_SETTINGS"
}

ensure_onboarding() {
  if [[ ! -f "$CLAUDE_JSON" ]]; then
    echo '{"hasCompletedOnboarding": true}' > "$CLAUDE_JSON"
  else
    python3 - "$CLAUDE_JSON" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
if not d.get("hasCompletedOnboarding"):
    d["hasCompletedOnboarding"] = True
    with open(path, "w") as f:
        json.dump(d, f, indent=2)
PYEOF
  fi
}

# ─── Config file for remembering last choices ────────────────────────────────
load_defaults() {
  DEFAULT_PLAN=""
  DEFAULT_MC_1=""
  DEFAULT_MC_2=""
  DEFAULT_MC_3=""
  SAVED_MINIMAX_API_KEY=""
  SAVED_DASHSCOPE_API_KEY=""
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  fi
  # Pre-populate env vars from saved keys if not already set
  if [[ -z "${MINIMAX_API_KEY:-}" && -n "$SAVED_MINIMAX_API_KEY" ]]; then export MINIMAX_API_KEY="$SAVED_MINIMAX_API_KEY"; fi
  if [[ -z "${DASHSCOPE_API_KEY:-}" && -n "$SAVED_DASHSCOPE_API_KEY" ]]; then export DASHSCOPE_API_KEY="$SAVED_DASHSCOPE_API_KEY"; fi
}

# Trap to restore settings on interrupt
trap 'restore_settings; exit 130' INT TERM

save_defaults() {
  # Quote API keys to preserve special characters
  cat > "$CONFIG_FILE" <<EOF
DEFAULT_PLAN=$PLAN_CHOICE
DEFAULT_MC_1=$DEFAULT_MC_1
DEFAULT_MC_2=$DEFAULT_MC_2
DEFAULT_MC_3=$DEFAULT_MC_3
SAVED_MINIMAX_API_KEY="${MINIMAX_API_KEY:-}"
SAVED_DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY:-}"
EOF
  chmod 600 "$CONFIG_FILE"
}

# ─── Helpers ─────────────────────────────────────────────────────────────────
print_header() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "  ╔════════════════════════════════════════╗"
  echo "  ║         Claude Code Launcher           ║"
  echo "  ╚════════════════════════════════════════╝"
  echo -e "${RESET}"
}

print_menu() {
  local title="$1"; shift
  echo -e "${YELLOW}${BOLD}  $title${RESET}"
  echo -e "${DIM}  ─────────────────────────────────────────${RESET}"
  local i=1
  for label in "$@"; do
    # Skip separator lines (lines starting with ─)
    # Skip section headers (lines ending with :)
    if [[ "$label" =~ ^[[:space:]]*─ ]] || [[ "$label" =~ :$ ]]; then
      echo -e "${DIM}  $label${RESET}"
    else
      printf "  ${GREEN}[%d]${RESET} %s\n" "$i" "$label"
      i=$((i + 1))
    fi
  done
  echo ""
}

# pick <prompt> <max> [default]
pick() {
  local prompt="$1"
  local max="$2"
  local default="${3:-}"
  local choice
  while true; do
    if [[ -n "$default" ]]; then
      read -rp "  $prompt [1-$max] (default: $default): " choice
      if [[ -z "$choice" ]]; then choice="$default"; fi
    else
      read -rp "  $prompt [1-$max]: " choice
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= max )); then
      echo "$choice"; return
    fi
    echo -e "  ${YELLOW}Please enter a number between 1 and $max.${RESET}"
  done
}

require_key() {
  local var="$1"
  local label="$2"
  local key="${!var:-}"
  if [[ -z "$key" ]]; then
    read -rsp "  Enter $label API key: " key
    echo ""
    if [[ -z "$key" ]]; then
      echo -e "  ${RED}Error:${RESET} No API key provided." >&2
      exit 1
    fi
    export "$var"="$key"
  fi
}

# ─── Claude Code installation check ──────────────────────────────────────────
check_claude_code() {
  echo -e "${CYAN}${BOLD}  Checking Claude Code installation...${RESET}"

  # Check if claude is installed
  if ! command -v claude &>/dev/null; then
    echo ""
    echo -e "${YELLOW}Claude Code is not installed.${RESET}"
    echo ""
    echo "Claude Code is required to use this launcher."
    echo ""
    read -rp "  Install Claude Code now? [Y/n]: " install_choice
    echo ""

    if [[ -z "$install_choice" || "$install_choice" =~ ^[Yy]$ ]]; then
      echo -e "${CYAN}Installing Claude Code...${RESET}"
      echo ""

      # Use the official install command
      if ! curl -sSL https://claude.ai/install.sh | bash; then
        echo ""
        echo -e "${RED}Error: Failed to install Claude Code.${RESET}"
        echo ""
        echo "You can manually install it with:"
        echo "  curl -sSL https://claude.ai/install.sh | bash"
        echo ""
        echo "Or visit: https://claude.ai/code"
        exit 1
      fi

      # Re-check if installation succeeded
      if ! command -v claude &>/dev/null; then
        echo ""
        echo -e "${YELLOW}Installation completed but 'claude' command not found.${RESET}"
        echo "Please restart your terminal or run:"
        echo "  source ~/.bashrc  # or ~/.zshrc"
        exit 1
      fi

      echo ""
      echo -e "${GREEN}✓ Claude Code installed successfully!${RESET}"
      echo ""
    else
      echo "Installation cancelled. Claude Code is required."
      exit 1
    fi
  else
    # Claude is installed, check for updates
    local current_version
    current_version=$(claude --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[[0-9]+(\.[0-9]+)?' | head -n1 || echo "unknown")

    echo -e "  ${DIM}Current version:${RESET} ${current_version}"
    echo ""

    # Check for updates (non-blocking, just informative)
    echo -e "  ${DIM}Checking for updates...${RESET}"
    if claude update --dry-run &>/dev/null 2>&1; then
      # Try to run actual update check
      if ! claude update --check &>/dev/null 2>&1; then
        # Alternative: try to get latest version info
        local latest_version
        latest_version=$(curl -s https://api.github.com/repos/anthropics/claude-code/releases/latest 2>/dev/null | grep -oE '"tag_name": "[^"]+"' | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || echo "")

        if [[ -n "$latest_version" && "$latest_version" != "$current_version" ]]; then
          echo ""
          echo -e "${YELLOW}Update available:${RESET} ${current_version} → ${GREEN}${latest_version}${RESET}"
          read -rp "  Update now? [y/N]: " update_choice
          echo ""

          if [[ "$update_choice" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Updating Claude Code...${RESET}"
            if claude update; then
              echo ""
              echo -e "${GREEN}✓ Update successful!${RESET}"
            else
              echo ""
              echo -e "${YELLOW}Update failed. You can retry later with:${RESET} claude update"
            fi
            echo ""
          fi
        else
          echo -e "  ${GREEN}✓ Up to date${RESET}"
          echo ""
        fi
      else
        echo -e "  ${GREEN}✓ Up to date${RESET}"
        echo ""
      fi
    fi
  fi

  sleep 1
}

# ─────────────────────────────────────────────────────────────────────────────
#  Load saved defaults
# ─────────────────────────────────────────────────────────────────────────────
load_defaults

# ─── Check Claude Code installation before proceeding ──────────────────────────
check_claude_code

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 1 — Select Provider
# ─────────────────────────────────────────────────────────────────────────────
print_header
print_menu "Select Provider:" \
  "[Anthropic] Claude Code   — Claude models via Anthropic API" \
  "[MiniMaxi]  MiniMaxi      — MiniMax API with MiniMax models" \
  "[Bailian]   Bailian       — Alibaba DashScope / Qwen models"

PLAN_CHOICE=$(pick "Provider" 3 "$DEFAULT_PLAN")

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 2 — Select Model  (provider-aware)
# ─────────────────────────────────────────────────────────────────────────────
echo ""

SELECTED_MODEL=""
PROVIDER="anthropic"         # anthropic | minimaxi | bailian
BASE_URL=""
API_KEY_VAR=""
EXTRA_ARGS=()

case "$PLAN_CHOICE" in

  # ── Anthropic (1) ────────────────────────────────────────────────────────
  1)
    PROVIDER="anthropic"
    restore_settings
    print_menu "Select Claude Model:" \
      "Opus 4.6    — Most capable, complex reasoning & architecture" \
      "Sonnet 4.6  — Balanced speed & intelligence  (default)" \
      "Haiku 4.5   — Fastest, lightweight tasks"
    MC=$(pick "Model" 3 "$DEFAULT_MC_1")
    DEFAULT_MC_1=$MC
    case "$MC" in
      1) SELECTED_MODEL="claude-opus-4-6" ;;
      2) SELECTED_MODEL="claude-sonnet-4-6" ;;
      3) SELECTED_MODEL="claude-haiku-4-5-20251001" ;;
    esac
    EXTRA_ARGS+=(--effort high) ;;

  # ── MiniMaxi (2) ─────────────────────────────────────────────────────────
  2)
    PROVIDER="minimaxi"
    BASE_URL="https://api.minimaxi.com/anthropic"
    API_KEY_VAR="MINIMAX_API_KEY"
    require_key "$API_KEY_VAR" "MiniMax"

    print_menu "Select MiniMaxi Model:" \
      "─────────────────────────────────────────" \
      "Recommended Model:" \
      "  MiniMax-M2.5           — Latest flagship, strong coding and reasoning" \
      "─────────────────────────────────────────" \
      "More Models:" \
      "  MiniMax-M2.5-highspeed — Same as M2.5, faster inference" \
      "  MiniMax-M2.1           — 230B parameters, multilingual and code" \
      "  MiniMax-M2             — 200k context, agentic calls"
    MC=$(pick "Model" 4 "$DEFAULT_MC_2")
    DEFAULT_MC_2=$MC
    case "$MC" in
      1) SELECTED_MODEL="MiniMax-M2.5" ;;
      2) SELECTED_MODEL="MiniMax-M2.5-highspeed" ;;
      3) SELECTED_MODEL="MiniMax-M2.1" ;;
      4) SELECTED_MODEL="MiniMax-M2" ;;
    esac

    write_minimax_settings "${MINIMAX_API_KEY}" "${SELECTED_MODEL}"
    ensure_onboarding

    EXTRA_ARGS+=(
      --effort medium
      --append-system-prompt "You are using the MiniMax API. Leverage MiniMax model strengths for text generation, reasoning, and code tasks."
    ) ;;

  # ─── Bailian / DashScope (3) ───────────────────────────────────────────────
  3)
    PROVIDER="bailian"
    BASE_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic"
    API_KEY_VAR="DASHSCOPE_API_KEY"
    restore_settings
    require_key "$API_KEY_VAR" "Alibaba DashScope"

    print_menu "Select Bailian / Qwen Model:" \
      "kimi-k2.5            — Kimi K2.5 model" \
      "glm-5                — GLM-5 model (Yiyan)" \
      "qwen3-max-2026-01-23 — Latest Qwen flagship" \
      "qwen3-coder-next     — Coding specialized" \
      "qwen3-coder-plus     — Coding enhanced" \
      "glm-4.7              — GLM-4.7 model" \
      "qwen3-flash          — Fast inference" \
      "qwen-turbo           — Fast and economical" \
      "qwen-long            — Long context (1M tokens)" \
      "qwq-plus             — Reasoning model"
    MC=$(pick "Model" 10 "$DEFAULT_MC_3")
    DEFAULT_MC_3=$MC
    case "$MC" in
      1) SELECTED_MODEL="kimi-k2.5" ;;
      2) SELECTED_MODEL="glm-5" ;;
      3) SELECTED_MODEL="qwen3-max-2026-01-23" ;;
      4) SELECTED_MODEL="qwen3-coder-next" ;;
      5) SELECTED_MODEL="qwen3-coder-plus" ;;
      6) SELECTED_MODEL="glm-4.7" ;;
      7) SELECTED_MODEL="qwen3-flash" ;;
      8) SELECTED_MODEL="qwen-turbo" ;;
      9) SELECTED_MODEL="qwen-long" ;;
      10) SELECTED_MODEL="qwq-plus" ;;
    esac

    # Write Bailian settings for Claude Code (after model is selected)
    write_bailian_settings "${!API_KEY_VAR}" "$SELECTED_MODEL"
    ensure_onboarding

    EXTRA_ARGS+=(
      --effort medium
      --append-system-prompt "You are using Alibaba Bailian (DashScope) with Qwen models. Leverage Qwen's strengths in multilingual tasks, long-context understanding, and coding."
    ) ;;

esac

# ─── Save choices for next run ────────────────────────────────────────────────
save_defaults

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 3 — Apply provider env overrides
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$PROVIDER" != "anthropic" ]]; then
  export ANTHROPIC_BASE_URL="$BASE_URL"
  export ANTHROPIC_AUTH_TOKEN="${!API_KEY_VAR}"
fi

if [[ "$PROVIDER" == "minimaxi" ]]; then
  export API_TIMEOUT_MS="3000000"
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
  export ANTHROPIC_MODEL="$SELECTED_MODEL"
  export ANTHROPIC_SMALL_FAST_MODEL="$SELECTED_MODEL"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="$SELECTED_MODEL"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="$SELECTED_MODEL"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="$SELECTED_MODEL"
fi

PROVIDER_NAMES=("" "Claude Code" "MiniMaxi" "Bailian")
PROVIDER_LABEL="${PROVIDER_NAMES[$PLAN_CHOICE]}"

# ─── Summary & Launch ────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}  Starting Claude Code${RESET}"
echo -e "  ${DIM}Provider:${RESET} ${YELLOW}${PROVIDER_LABEL}${RESET}"
echo -e "  ${DIM}Model   :${RESET} ${BLUE}${SELECTED_MODEL}${RESET}"
[[ -n "$BASE_URL" ]] && echo -e "  ${DIM}Endpoint:${RESET} ${DIM}${BASE_URL}${RESET}"
echo ""
echo -e "  ${DIM}Press Ctrl+C to cancel...${RESET}"
sleep 1

exec claude --model "$SELECTED_MODEL" --dangerously-skip-permissions "${EXTRA_ARGS[@]}"
