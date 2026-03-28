#!/usr/bin/env bash
# start-claude-ubuntu.sh — Interactive launcher for Claude Code (Ubuntu/Linux)
# Supports Anthropic, MiniMaxi, and Bailian (DashScope) providers

set -euo pipefail

# ─── Re-run with PTY if stdin is not a terminal ─────────────────────────────
if [[ ! -t 0 ]]; then
  # Ubuntu's 'script' command requires -c for command execution
  # and -q for quiet mode (not all versions support it)
  if script --version 2>/dev/null | grep -q "GNU"; then
    # GNU script (Linux) - use -c flag
    exec script -q -c "$0 $*" /dev/null 2>/dev/null || \
    exec script -c "$0 $*" /dev/null 2>/dev/null
  else
    # BSD script (macOS compatibility)
    exec script -q /dev/null "$0" "$@"
  fi
fi

# ─── Version & Update ─────────────────────────────────────────────────────
VERSION="1.2.5"
UPDATE_URL="https://raw.githubusercontent.com/yylonly/claude-launcher/main/start-claude.sh"
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ -L "$SCRIPT_PATH" ]]; then
    SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH")"
fi

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

# ─── Auto-update function ───────────────────────────────────────────────────
check_update() {
    echo -e "${CYAN}Checking for updates...${RESET}"

    # Get remote version
    local remote_version
    remote_version=$(curl -sSL "$UPDATE_URL" 2>/dev/null | grep -m1 '^VERSION=' | cut -d'"' -f2 || echo "")

    if [[ -z "$remote_version" ]]; then
        echo -e "${YELLOW}Could not check for updates.${RESET}"
        return 1
    fi

    if [[ "$remote_version" != "$VERSION" ]]; then
        echo -e "${YELLOW}Update available:${RESET} v${VERSION} → v${remote_version}"
        echo ""
        read -rp "  Update now? [y/N]: " update_choice
        if [[ "$update_choice" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Updating...${RESET}"
            if curl -sSL "$UPDATE_URL" -o "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH"; then
                echo -e "${GREEN}✓ Updated successfully!${RESET}"
                echo "Please run again."
                exit 0
            else
                echo -e "${RED}Update failed.${RESET}"
                return 1
            fi
        fi
    else
        echo -e "${GREEN}✓ Up to date (v${VERSION})${RESET}"
    fi
    return 0
}

# ─── settings.json helpers ───────────────────────────────────────────────────
write_minimax_settings() {
  local api_key="$1"
  local model="$2"
  local agent_teams="${3:-}"
  mkdir -p "${HOME}/.claude"
  # Backup original settings once
  if [[ -f "$CLAUDE_SETTINGS" && ! -f "$CLAUDE_SETTINGS_BAK" ]]; then
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS_BAK"
  fi

  # Build env JSON
  local env_json
  if [[ "$agent_teams" == "1" ]]; then
    env_json="{\"ANTHROPIC_BASE_URL\": \"https://api.minimaxi.com/anthropic\", \"ANTHROPIC_AUTH_TOKEN\": \"${api_key}\", \"API_TIMEOUT_MS\": \"3000000\", \"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC\": \"1\", \"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS\": \"1\", \"ANTHROPIC_MODEL\": \"${model}\", \"ANTHROPIC_SMALL_FAST_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_SONNET_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_OPUS_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_HAIKU_MODEL\": \"${model}\"}"
  else
    env_json="{\"ANTHROPIC_BASE_URL\": \"https://api.minimaxi.com/anthropic\", \"ANTHROPIC_AUTH_TOKEN\": \"${api_key}\", \"API_TIMEOUT_MS\": \"3000000\", \"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC\": \"1\", \"ANTHROPIC_MODEL\": \"${model}\", \"ANTHROPIC_SMALL_FAST_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_SONNET_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_OPUS_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_HAIKU_MODEL\": \"${model}\"}"
  fi

  # Merge with existing settings using python (preserve other config)
  python3 - "$CLAUDE_SETTINGS" "$env_json" <<'PYEOF'
import json, sys
settings_path, env_json = sys.argv[1], sys.argv[2]
env = json.loads(env_json)
try:
    with open(settings_path) as f:
        settings = json.load(f)
except:
    settings = {}
settings['env'] = env
settings['skipDangerousModePermissionPrompt'] = True
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF
  chmod 600 "$CLAUDE_SETTINGS"
}

restore_settings() {
  if [[ -f "$CLAUDE_SETTINGS_BAK" ]]; then
    cp "$CLAUDE_SETTINGS_BAK" "$CLAUDE_SETTINGS"
  else
    rm -f "$CLAUDE_SETTINGS"
  fi
}

write_anthropic_settings() {
  local model="$1"
  mkdir -p "${HOME}/.claude"
  python3 - "$CLAUDE_SETTINGS" "$model" <<'PYEOF'
import json, sys
settings_path, model = sys.argv[1], sys.argv[2]
try:
    with open(settings_path) as f:
        settings = json.load(f)
except:
    settings = {}
settings['model'] = model
settings['skipDangerousModePermissionPrompt'] = True
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF
}

write_bailian_settings() {
  local api_key="$1"
  local model="$2"
  local agent_teams="${3:-}"
  mkdir -p "${HOME}/.claude"
  # Backup original settings once
  if [[ -f "$CLAUDE_SETTINGS" && ! -f "$CLAUDE_SETTINGS_BAK" ]]; then
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS_BAK"
  fi

  # Build env JSON
  local env_json
  if [[ "$agent_teams" == "1" ]]; then
    env_json="{\"ANTHROPIC_BASE_URL\": \"https://coding.dashscope.aliyuncs.com/apps/anthropic\", \"ANTHROPIC_AUTH_TOKEN\": \"${api_key}\", \"API_TIMEOUT_MS\": \"3000000\", \"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC\": \"1\", \"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS\": \"1\", \"ANTHROPIC_MODEL\": \"${model}\", \"ANTHROPIC_SMALL_FAST_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_SONNET_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_OPUS_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_HAIKU_MODEL\": \"${model}\"}"
  else
    env_json="{\"ANTHROPIC_BASE_URL\": \"https://coding.dashscope.aliyuncs.com/apps/anthropic\", \"ANTHROPIC_AUTH_TOKEN\": \"${api_key}\", \"API_TIMEOUT_MS\": \"3000000\", \"CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC\": \"1\", \"ANTHROPIC_MODEL\": \"${model}\", \"ANTHROPIC_SMALL_FAST_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_SONNET_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_OPUS_MODEL\": \"${model}\", \"ANTHROPIC_DEFAULT_HAIKU_MODEL\": \"${model}\"}"
  fi

  # Merge with existing settings using python (preserve other config)
  python3 - "$CLAUDE_SETTINGS" "$env_json" <<'PYEOF'
import json, sys
settings_path, env_json = sys.argv[1], sys.argv[2]
env = json.loads(env_json)
try:
    with open(settings_path) as f:
        settings = json.load(f)
except:
    settings = {}
settings['env'] = env
settings['skipDangerousModePermissionPrompt'] = True
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF
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
  DEFAULT_AGENT_TEAMS="2"  # 1=yes, 2=no
  DEFAULT_CLAUDE_HUD="1"   # 1=install, 2=skip
  DEFAULT_BRAVE_SEARCH="2" # 1=enable, 2=skip
  DEFAULT_TAVILY_SEARCH="2" # 1=enable, 2=skip
  SAVED_MINIMAX_API_KEY=""
  SAVED_DASHSCOPE_API_KEY=""
  SAVED_BRAVE_API_KEY=""
  SAVED_TAVILY_API_KEY=""
  LAST_PROJECT_DIR=""
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  fi
  # Ensure CLAUDE_HUD has a default if not in config
  DEFAULT_CLAUDE_HUD="${DEFAULT_CLAUDE_HUD:-1}"
  DEFAULT_BRAVE_SEARCH="${DEFAULT_BRAVE_SEARCH:-2}"
  DEFAULT_TAVILY_SEARCH="${DEFAULT_TAVILY_SEARCH:-2}"
  # Pre-populate env vars from saved keys if not already set
  if [[ -z "${MINIMAX_API_KEY:-}" && -n "$SAVED_MINIMAX_API_KEY" ]]; then export MINIMAX_API_KEY="$SAVED_MINIMAX_API_KEY"; fi
  if [[ -z "${DASHSCOPE_API_KEY:-}" && -n "$SAVED_DASHSCOPE_API_KEY" ]]; then export DASHSCOPE_API_KEY="$SAVED_DASHSCOPE_API_KEY"; fi
  if [[ -z "${BRAVE_API_KEY:-}" && -n "$SAVED_BRAVE_API_KEY" ]]; then export BRAVE_API_KEY="$SAVED_BRAVE_API_KEY"; fi
  if [[ -z "${TAVILY_API_KEY:-}" && -n "$SAVED_TAVILY_API_KEY" ]]; then export TAVILY_API_KEY="$SAVED_TAVILY_API_KEY"; fi
}

# Trap to restore settings on interrupt
trap 'restore_settings; exit 130' INT TERM

save_defaults() {
  # Determine project directory (current working directory or saved)
  if [[ -n "$LAST_PROJECT_DIR" ]]; then
    PROJECT_DIR="$LAST_PROJECT_DIR"
  else
    PROJECT_DIR="$(pwd)"
  fi
  # Quote API keys to preserve special characters
  cat > "$CONFIG_FILE" <<EOF
DEFAULT_PLAN=$PLAN_CHOICE
DEFAULT_MC_1=$DEFAULT_MC_1
DEFAULT_MC_2=$DEFAULT_MC_2
DEFAULT_MC_3=$DEFAULT_MC_3
DEFAULT_AGENT_TEAMS=$AGENT_TEAMS_CHOICE
DEFAULT_CLAUDE_HUD=$CLAUDE_HUD_CHOICE
DEFAULT_BRAVE_SEARCH=$BRAVE_SEARCH_CHOICE
DEFAULT_TAVILY_SEARCH=$TAVILY_SEARCH_CHOICE
SAVED_MINIMAX_API_KEY="${MINIMAX_API_KEY:-}"
SAVED_DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY:-}"
SAVED_BRAVE_API_KEY="${BRAVE_API_KEY:-}"
SAVED_TAVILY_API_KEY="${TAVILY_API_KEY:-}"
LAST_PROJECT_DIR="$PROJECT_DIR"
EOF
  chmod 600 "$CONFIG_FILE"
}

# ─── Helpers ─────────────────────────────────────────────────────────────────
print_header() {
  clear 2>/dev/null || true
  echo -e "${CYAN}${BOLD}"
  echo "  ╔════════════════════════════════════════╗"
  echo "  ║         Claude Code Launcher         ║"
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

# ─── Dependency check & install (Ubuntu/Debian) ──────────────────────────────
check_dependencies() {
  echo -e "${CYAN}${BOLD}  Checking dependencies...${RESET}"
  echo ""

  local missing_deps=()
  local missing_optional=()

  # Required dependencies
  local deps=("bash" "curl" "python3")
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing_deps+=("$dep")
    fi
  done

  # Claude Code (required)
  if ! command -v claude &>/dev/null; then
    missing_deps+=("claude")
  fi

  # Optional: bun or node (needed for Claude-HUD)
  local node_version=""
  if command -v node &>/dev/null; then
    node_version=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
  fi

  if ! command -v bun &>/dev/null && ! command -v node &>/dev/null; then
    missing_optional+=("bun")
  elif [[ -n "$node_version" && "$node_version" -lt 20 ]]; then
    echo -e "  ${YELLOW}⚠ Node.js v${node_version} detected (Claude-HUD requires >=20)${RESET}"
  fi

  # Report status
  echo -e "  ${GREEN}✓${RESET} bash: $(bash --version | head -1)"
  echo -e "  ${GREEN}✓${RESET} curl: $(curl --version | head -1 | awk '{print $1, $2}')"
  echo -e "  ${GREEN}✓${RESET} python3: $(python3 --version)"
  if command -v claude &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} claude: installed"
  else
    echo -e "  ${YELLOW}✗${RESET} claude: not installed"
  fi

  if command -v bun &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} bun: $(bun --version)"
  elif command -v node &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} node: $(node --version)"
  else
    echo -e "  ${DIM}○${RESET} bun/node: not installed (optional, for Claude-HUD)"
  fi

  # Install missing required dependencies using apt-get
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Missing required dependencies:${RESET} ${missing_deps[*]}"
    echo ""
    read -rp "  Install missing dependencies with apt-get? [Y/n]: " install_choice
    echo ""

    if [[ -z "$install_choice" || "$install_choice" =~ ^[Yy]$ ]]; then
      # Update package list first
      echo -e "  ${CYAN}Updating package list...${RESET}"
      sudo apt-get update 2>/dev/null || true

      for dep in "${missing_deps[@]}"; do
        echo -e "  ${CYAN}Installing $dep...${RESET}"
        if [[ "$dep" == "claude" ]]; then
          echo '  Follow the official guide: https://claude.ai/code'
          echo '  Or run: curl -sSL https://claude.ai/install.sh | bash'
        elif [[ "$dep" == "python3" ]]; then
          sudo apt-get install -y python3 || echo -e "  ${RED}Failed to install python3${RESET}"
        else
          sudo apt-get install -y "$dep" || echo -e "  ${RED}Failed to install $dep${RESET}"
        fi
      done

      # Re-check after installation
      echo ""
      echo -e "${CYAN}Re-checking dependencies...${RESET}"
      local still_missing=()
      for dep in "${missing_deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
          still_missing+=("$dep")
        fi
      done

      if [[ ${#still_missing[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Still missing:${RESET} ${still_missing[*]}"
        echo "Please install manually and run again."
        exit 1
      fi
    else
      echo "Cannot proceed without required dependencies."
      exit 1
    fi
  fi

  # Offer to install optional bun if missing or node version is old
  if [[ ${#missing_optional[@]} -gt 0 ]] || [[ "$node_version" -lt 20 2>/dev/null ]]; then
    echo ""
    echo -e "${DIM}Note: bun is recommended for Claude-HUD (Node.js <20 has compatibility issues)${RESET}"
    read -rp "  Install bun now? [y/N]: " install_bun
    echo ""

    if [[ "$install_bun" =~ ^[Yy]$ ]]; then
      echo -e "  ${CYAN}Installing bun...${RESET}"
      curl -fsSL https://bun.sh/install | bash || echo -e "  ${RED}Failed to install bun${RESET}"
    elif [[ -n "$node_version" && "$node_version" -lt 20 ]]; then
      echo -e "${YELLOW}⚠ Node.js v${node_version} may not work with Claude-HUD${RESET}"
      echo -e "  ${DIM}Consider installing Node.js 20+ or bun for full compatibility${RESET}"
    fi
  fi

  echo ""
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

      # Ensure ~/.local/bin is in PATH for this session
      export PATH="$HOME/.local/bin:$PATH"

      # Add to ~/.bashrc for persistence across sessions
      if ! grep -q '~/.local/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
      fi

      # Source ~/.bashrc to pick up updated PATH immediately
      source ~/.bashrc

      # Re-check if installation succeeded
      if ! command -v claude &>/dev/null; then
        echo ""
        echo -e "${YELLOW}Installation completed but 'claude' command not found.${RESET}"
        echo "Try running: source ~/.bashrc"
        echo "Or manually add to ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\""
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
    # Claude is installed, show version
    local current_version
    current_version=$(claude --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || echo "unknown")

    echo -e "  ${DIM}Current version:${RESET} ${current_version}"
    echo ""
    echo -e "  ${DIM}Tip: Run ${GREEN}claude update${DIM} to update Claude Code${RESET}"
    echo ""
  fi

}

# ─── Claude-hud plugin check and install ─────────────────────────────────────
check_claude_hud() {
  echo -e "${CYAN}${BOLD}  Checking Claude-hud plugin...${RESET}"

  local plugin_repo="jarrodwatts/claude-hud"

  # Try to add marketplace, install and enable plugin
  # Commands are idempotent - safe to run even if already installed
  echo -e "  ${CYAN}Setting up Claude-hud plugin...${RESET}"
  claude plugin marketplace add "$plugin_repo" 2>/dev/null | sed 's/^/  /' || true
  claude plugin install claude-hud 2>/dev/null | sed 's/^/  /' || true
  claude plugin enable claude-hud 2>/dev/null | sed 's/^/  /' || true

  # Configure the plugin with all features enabled (continue even if fails)
  if configure_claude_hud_all_features; then
    echo -e "  ${GREEN}✓${RESET} Claude-hud plugin is ready (all features enabled)"
  else
    echo -e "  ${YELLOW}⚠${RESET} Claude-hud configuration skipped (non-critical)"
  fi
  echo ""
}

# ─── Configure Claude-hud plugin with all features ───────────────────────────
configure_claude_hud_all_features() {
  echo -e "  ${CYAN}Configuring Claude-hud with all features...${RESET}"

  mkdir -p "${HOME}/.claude"

  # Backup original settings once
  if [[ -f "$CLAUDE_SETTINGS" && ! -f "$CLAUDE_SETTINGS_BAK" ]]; then
    cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS_BAK"
  fi

  # Get runtime path (prefer bun, fallback to node)
  local runtime_path
  runtime_path=$(command -v bun 2>/dev/null || command -v node 2>/dev/null)

  if [[ -z "$runtime_path" ]]; then
    echo -e "${YELLOW}⚠ No runtime found (bun/node), skipping HUD config${RESET}"
    return 0
  fi

  # Check Node.js version (bun handles this internally, but node needs >=20 for fs/promises.constants)
  if [[ "$runtime_path" == *"node" ]]; then
    local runtime_version
    runtime_version=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
    if [[ -n "$runtime_version" && "$runtime_version" -lt 20 ]]; then
      echo -e "${YELLOW}⚠ Node.js v${runtime_version} is too old for Claude-hud (requires >=20)${RESET}"
      echo -e "  ${DIM}Install bun for better compatibility: curl -fsSL https://bun.sh/install | bash${RESET}"
      return 0
    fi
  fi

  # Find the latest claude-hud version directory
  local plugin_dir
  plugin_dir=$(ls -d "$HOME/.claude/plugins/cache/claude-hud/claude-hud"/*/ 2>/dev/null | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)

  if [[ -z "$plugin_dir" ]]; then
    echo -e "${YELLOW}⚠ Claude-hud plugin directory not found, skipping HUD config${RESET}"
    return 0
  fi

  # Generate statusline command
  local statusline_cmd="exec ${runtime_path} ${plugin_dir}/src/index.ts"

  # Write settings using Python - create temp script to avoid heredoc issues
  local temp_py=$(mktemp).py
  cat > "$temp_py" <<PYEOF
import json, sys
settings_path = sys.argv[1]
statusline_cmd = sys.argv[2]
try:
    with open(settings_path) as f:
        settings = json.load(f)
except:
    settings = {}
if 'enabledPlugins' not in settings:
    settings['enabledPlugins'] = {}
settings['enabledPlugins']['claude-hud'] = True
settings['enabledPlugins']['claude-hud@claude-hud'] = True
if 'extraKnownMarketplaces' not in settings:
    settings['extraKnownMarketplaces'] = {}
settings['extraKnownMarketplaces']['claude-hud'] = {"source": {"source": "github", "repo": "jarrodwatts/claude-hud"}}
settings['statusLine'] = {"type": "command", "command": statusline_cmd}
settings['skipDangerousModePermissionPrompt'] = True
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF

  echo -e "  ${DIM}Writing settings...${RESET}"
  python3 "$temp_py" "$CLAUDE_SETTINGS" "$statusline_cmd"
  local python_exit=$?
  rm -f "$temp_py"

  if [[ $python_exit -ne 0 ]]; then
    echo -e "${RED}✗ Python config failed (exit $python_exit)${RESET}"
    return 0
  fi

  # Create config file with all features enabled
  local plugin_config_dir="${HOME}/.claude/plugins/claude-hud"
  mkdir -p "$plugin_config_dir"

  cat > "$plugin_config_dir/config.json" <<'EOF'
{
  "display": {
    "showTools": true,
    "showAgents": true,
    "showTodos": true,
    "showDuration": true,
    "showConfigCounts": true,
    "showSessionName": true
  }
}
EOF

  chmod 600 "$CLAUDE_SETTINGS" 2>/dev/null || true
  echo -e "  ${GREEN}✓ Claude-hud configured with all features!${RESET}"
}

# ─── Configure Brave Search MCP ─────────────────────────────────────────────────
configure_brave_search() {
  local api_key="$1"

  echo -e "  ${CYAN}Configuring Brave Search MCP...${RESET}"

  # Use python to update settings.json with Brave MCP
  python3 - "$CLAUDE_SETTINGS" "$api_key" <<'PYEOF' | sed 's/^/  /'
import json
import sys

settings_path = sys.argv[1]
brave_key = sys.argv[2]

settings = {}
try:
    with open(settings_path) as f:
        settings = json.load(f)
except:
    pass

# Add extraKnownMarketplaces for brave-search
if 'extraKnownMarketplaces' not in settings:
    settings['extraKnownMarketplaces'] = {}

# Ensure enabledPlugins exists
if 'enabledPlugins' not in settings:
    settings['enabledPlugins'] = {}

# Add brave-search marketplace (already handled by claude-mcp-servers usually)
# Just ensure the permission is set in settings.local.json
settings['skipDangerousModePermissionPrompt'] = True

# Write to settings.json (but actual MCP server config goes to .claude.json per project)
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

# Add Brave Search MCP to project-level config
import os
claude_json_path = os.path.join(os.path.expanduser('~'), '.claude.json')

# Load existing project configs
try:
    with open(claude_json_path) as f:
        claude_data = json.load(f)
except:
    claude_data = {}

# Get current working directory project
import subprocess
try:
    cwd = subprocess.check_output(['pwd']).decode().strip()
except:
    cwd = os.getcwd()

# Find project in claude_data
if 'projects' not in claude_data:
    claude_data['projects'] = {}

if cwd not in claude_data['projects']:
    claude_data['projects'][cwd] = {}

project_config = claude_data['projects'][cwd]

# Add MCP server config
if 'mcpServers' not in project_config:
    project_config['mcpServers'] = {}

project_config['mcpServers']['brave-search'] = {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-brave-search"],
    "env": {
        "BRAVE_API_KEY": brave_key
    }
}

claude_data['projects'][cwd] = project_config

with open(claude_json_path, 'w') as f:
    json.dump(claude_data, f, indent=2)

print("Brave Search MCP configured successfully")
PYEOF

  echo -e "  ${GREEN}✓ Brave Search MCP configured!${RESET}"
}

# ─── Configure Tavily MCP ────────────────────────────────────────────────────────
configure_tavily_search() {
  local api_key="$1"

  echo -e "  ${CYAN}Configuring Tavily MCP...${RESET}"

  # Use python to update .claude.json with Tavily MCP
  python3 - "$api_key" <<'PYEOF' | sed 's/^/  /'
import json
import sys
import os

api_key = sys.argv[1]

claude_json_path = os.path.join(os.path.expanduser('~'), '.claude.json')

# Load existing project configs
try:
    with open(claude_json_path) as f:
        claude_data = json.load(f)
except:
    claude_data = {}

# Get current working directory project
import subprocess
try:
    cwd = subprocess.check_output(['pwd']).decode().strip()
except:
    cwd = os.getcwd()

# Find project in claude_data
if 'projects' not in claude_data:
    claude_data['projects'] = {}

if cwd not in claude_data['projects']:
    claude_data['projects'][cwd] = {}

project_config = claude_data['projects'][cwd]

# Add MCP server config - using Tavily remote MCP
if 'mcpServers' not in project_config:
    project_config['mcpServers'] = {}

project_config['mcpServers']['tavily'] = {
    "type": "http",
    "url": f"https://mcp.tavily.com/mcp/?tavilyApiKey={api_key}"
}

claude_data['projects'][cwd] = project_config

with open(claude_json_path, 'w') as f:
    json.dump(claude_data, f, indent=2)

print("Tavily MCP configured successfully")
PYEOF

  echo -e "  ${GREEN}✓ Tavily MCP configured!${RESET}"
}

# ─── Update settings.local.json with MCP permissions ─────────────────────────────
update_mcp_permissions() {
  echo -e "  ${CYAN}Updating MCP permissions...${RESET}"

  local settings_local="${HOME}/.claude/settings.local.json"

  # Ensure directory exists
  mkdir -p "$(dirname "$settings_local")"

  # Create or update settings.local.json
  python3 - "$settings_local" <<'PYEOF' | sed 's/^/  /'
import json
import sys
import os

settings_local_path = sys.argv[1]

# Load existing or create new
try:
    with open(settings_local_path) as f:
        settings = json.load(f)
except:
    settings = {"permissions": {"allow": []}}

if "permissions" not in settings:
    settings["permissions"] = {"allow": []}

if "allow" not in settings["permissions"]:
    settings["permissions"]["allow"] = []

# Add MCP permissions if not already present
permissions_to_add = [
    "mcp__context7__resolve-library-id",
    "mcp__context7__query-docs",
    "mcp__brave-search__brave_web_search",
    "mcp__brave-search__brave_image_search",
    "mcp__brave-search__brave_news_search",
    "mcp__tavily__tavily_search",
    "mcp__tavily__tavily_extract",
    "mcp__tavily__tavily_crawl",
    "mcp__tavily__tavily_map",
    "mcp__tavily__tavily_research"
]

for perm in permissions_to_add:
    if perm not in settings["permissions"]["allow"]:
        settings["permissions"]["allow"].append(perm)

with open(settings_local_path, 'w') as f:
    json.dump(settings, f, indent=2)

print("MCP permissions updated")
PYEOF

  echo -e "  ${GREEN}✓ MCP permissions updated!${RESET}"
}

# ─── Quick launch with saved config ─────────────────────────────────────────
quick_launch() {
  PLAN_CHOICE="$DEFAULT_PLAN"
  AGENT_TEAMS_CHOICE="${DEFAULT_AGENT_TEAMS:-2}"
  CLAUDE_HUD_CHOICE="${DEFAULT_CLAUDE_HUD:-1}"
  BRAVE_SEARCH_CHOICE="${DEFAULT_BRAVE_SEARCH:-2}"
  TAVILY_SEARCH_CHOICE="${DEFAULT_TAVILY_SEARCH:-2}"

  # Save current directory for resume
  LAST_PROJECT_DIR="$(pwd)"

  SELECTED_MODEL=""
  PROVIDER=""
  BASE_URL=""
  API_KEY_VAR=""
  EXTRA_ARGS=()

  case "$PLAN_CHOICE" in
    1)  # Anthropic
      PROVIDER="anthropic"
      restore_settings
      case "${DEFAULT_MC_1:-2}" in
        1) SELECTED_MODEL="claude-opus-4-6" ;;
        2) SELECTED_MODEL="claude-sonnet-4-6" ;;
        3) SELECTED_MODEL="claude-haiku-4-5-20251001" ;;
        *) SELECTED_MODEL="claude-sonnet-4-6" ;;
      esac
      ;;

    2)  # MiniMaxi
      PROVIDER="minimaxi"
      BASE_URL="https://api.minimaxi.com/anthropic"
      API_KEY_VAR="MINIMAX_API_KEY"

      if [[ -z "${!API_KEY_VAR:-}" ]]; then
        echo -e "${RED}Error: MiniMax API key not found.${RESET}"
        echo "Run with -c to configure."
        exit 1
      fi

      case "${DEFAULT_MC_2:-1}" in
        1) SELECTED_MODEL="MiniMax-M2.7" ;;
        2) SELECTED_MODEL="MiniMax-M2.7-highspeed" ;;
        3) SELECTED_MODEL="MiniMax-M2.5" ;;
        4) SELECTED_MODEL="MiniMax-M2.5-highspeed" ;;
        5) SELECTED_MODEL="MiniMax-M2.1" ;;
        6) SELECTED_MODEL="MiniMax-M2" ;;
        *) SELECTED_MODEL="MiniMax-M2.7" ;;
      esac

      write_minimax_settings "${!API_KEY_VAR}" "$SELECTED_MODEL" "$AGENT_TEAMS_CHOICE"
      ensure_onboarding

      EXTRA_ARGS+=(
        --append-system-prompt "You are using the MiniMax API. Leverage MiniMax model strengths for text generation, reasoning, and code tasks."
      )
      ;;

    3)  # Bailian
      PROVIDER="bailian"
      BASE_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic"
      API_KEY_VAR="DASHSCOPE_API_KEY"
      restore_settings

      if [[ -z "${!API_KEY_VAR:-}" ]]; then
        echo -e "${RED}Error: DashScope API key not found.${RESET}"
        echo "Run with -c to configure."
        exit 1
      fi

      case "${DEFAULT_MC_3:-1}" in
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
        *) SELECTED_MODEL="qwen3-max-2026-01-23" ;;
      esac

      write_bailian_settings "${!API_KEY_VAR}" "$SELECTED_MODEL" "$AGENT_TEAMS_CHOICE"
      ensure_onboarding

      EXTRA_ARGS+=(
        --append-system-prompt "You are using Alibaba Bailian (DashScope) with Qwen models. Leverage Qwen's strengths in multilingual tasks, long-context understanding, and coding."
      )
      ;;

    *)
      echo -e "${RED}Invalid provider in config: $DEFAULT_PLAN${RESET}"
      echo "Run with -c to reconfigure."
      exit 1
      ;;
  esac

  # Set environment variables
  if [[ "$PROVIDER" != "anthropic" ]]; then
    export ANTHROPIC_BASE_URL="$BASE_URL"
    export ANTHROPIC_AUTH_TOKEN="${!API_KEY_VAR}"
  fi

  if [[ "$AGENT_TEAMS_CHOICE" == "1" ]]; then
    export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"
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

  echo -e "${CYAN}${BOLD}  Starting Claude Code${RESET}"
  echo -e "  ${DIM}Provider:${RESET} ${YELLOW}${PROVIDER_LABEL}${RESET}"
  echo -e "  ${DIM}Model   :${RESET} ${BLUE}${SELECTED_MODEL}${RESET}"
  [[ -n "$BASE_URL" ]] && echo -e "  ${DIM}Endpoint:${RESET} ${DIM}${BASE_URL}${RESET}"
  if [[ "$AGENT_TEAMS_CHOICE" == "1" ]]; then
    echo -e "  ${DIM}Agent   :${RESET} ${GREEN}Enabled${RESET}"
  fi
  echo ""

  # Save config including project directory for resume
  save_defaults

  exec claude --model "opus[1m]" --permission-mode bypassPermissions "${EXTRA_ARGS[@]}"
}

# ─── Uninstall Subcommand ─────────────────────────────────────────────────────
run_uninstall() {
  INSTALL_NAME="claude-launcher"
  ALIAS_NAME="start-claude"
  CONFIG_FILE="${HOME}/.claude-launcher.conf"
  CLAUDE_SETTINGS_BAK="${HOME}/.claude/settings.json.launcher-bak"

  echo -e "${BOLD}Claude Launcher Uninstaller${RESET}"
  echo "============================"
  echo ""

  find_install_dir() {
    if command -v "$INSTALL_NAME" &>/dev/null; then
        dirname "$(command -v "$INSTALL_NAME")"
        return
    fi
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

  if [[ -n "$INSTALL_DIR" && -d "$INSTALL_DIR" ]]; then
    [[ -f "${INSTALL_DIR}/${INSTALL_NAME}" ]] && FOUND_FILES+=("${INSTALL_DIR}/${INSTALL_NAME}")
    [[ -L "${INSTALL_DIR}/${ALIAS_NAME}" ]] && FOUND_FILES+=("${INSTALL_DIR}/${ALIAS_NAME}")
    [[ -L "${INSTALL_DIR}/cli" ]] && FOUND_FILES+=("${INSTALL_DIR}/cli")
    [[ -f "${INSTALL_DIR}/delete-plugin.sh" || -L "${INSTALL_DIR}/delete-plugin" ]] && FOUND_FILES+=("${INSTALL_DIR}/delete-plugin.sh")
    [[ -f "${INSTALL_DIR}/delete-mcp.sh" || -L "${INSTALL_DIR}/delete-mcp" ]] && FOUND_FILES+=("${INSTALL_DIR}/delete-mcp.sh")
  fi

  FOUND_CONFIGS=()
  [[ -f "$CONFIG_FILE" ]] && FOUND_CONFIGS+=("$CONFIG_FILE")
  [[ -f "$CLAUDE_SETTINGS_BAK" ]] && FOUND_CONFIGS+=("$CLAUDE_SETTINGS_BAK")

  if [[ ${#FOUND_FILES[@]} -eq 0 && ${#FOUND_CONFIGS[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No claude-launcher installation found.${RESET}"
    return 0
  fi

  echo "The following files will be removed:"
  echo ""

  if [[ ${#FOUND_FILES[@]} -gt 0 ]]; then
    echo -e "${CYAN}Installed binaries:${RESET}"
    for f in "${FOUND_FILES[@]}"; do
      echo "  - $f"
    done
    echo ""
  fi

  if [[ ${#FOUND_CONFIGS[@]} -gt 0 ]]; then
    echo -e "${CYAN}Configuration files:${RESET}"
    for f in "${FOUND_CONFIGS[@]}"; do
      echo "  - $f"
    done
    echo ""
  fi

  read -p "Do you want to proceed? [y/N]: " confirm
  echo ""

  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    return 0
  fi

  REMOVED_COUNT=0
  for file in "${FOUND_FILES[@]}"; do
    if [[ -f "$file" || -L "$file" ]]; then
      echo -n "Removing ${file}... "
      if [[ -w "$(dirname "$file")" ]]; then
        rm -f "$file"
      else
        sudo rm -f "$file"
      fi
      echo -e "${GREEN}Done${RESET}"
      ((REMOVED_COUNT++)) || true
    fi
  done

  if [[ ${#FOUND_CONFIGS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Configuration files found:${RESET}"
    for f in "${FOUND_CONFIGS[@]}"; do
      echo "  - $f"
    done
    echo ""
    read -p "Remove configuration files as well? [y/N]: " remove_config
    echo ""

    if [[ "$remove_config" =~ ^[Yy]$ ]]; then
      for f in "${FOUND_CONFIGS[@]}"; do
        if [[ -f "$f" ]]; then
          echo -n "Removing ${f}... "
          rm -f "$f"
          echo -e "${GREEN}Done${RESET}"
        fi
      done

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
}

# ─── MCP Subcommand ───────────────────────────────────────────────────────────
run_mcp() {
  CLAUDE_JSON="${HOME}/.claude.json"

  mcp_usage() {
    echo "Usage: cli mcp [options]"
    echo ""
    echo "Options:"
    echo "  -l, --list     List all local MCP servers"
    echo "  -d, --delete   Delete a specific MCP server (interactive)"
    echo "  -a, --all      Delete all local MCP servers"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  cli mcp -l              # List all MCP servers"
    echo "  cli mcp -d brave-search # Delete brave-search MCP"
    echo "  cli mcp -a              # Delete all MCP servers"
  }

  list_mcps() {
    echo -e "${CYAN}Local MCP Servers:${RESET}"
    echo ""

    if [[ ! -f "$CLAUDE_JSON" ]]; then
      echo -e "${YELLOW}No .claude.json found.${RESET}"
      return
    fi

    python3 - "$CLAUDE_JSON" <<'PYEOF'
import json
import sys
import re

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

projects = data.get("projects", {})
mcp_count = 0

for project_path, project_data in projects.items():
    mcp_servers = project_data.get("mcpServers", {})
    if mcp_servers:
        print(f"Project: {project_path}")
        for name, config in mcp_servers.items():
            if config.get("type") == "stdio":
                cmd = " ".join(config.get("args", []))
                print(f"  - {name}: stdio {cmd}")
            elif config.get("type") == "http":
                url = config.get("url", "")
                masked = re.sub(r'(api[_-]?key=)[^&]+', r'\1***', url)
                print(f"  - {name}: http {masked}")
            mcp_count += 1
        print("")

if mcp_count == 0:
    print("No MCP servers found.")

PYEOF
  }

  delete_mcp() {
    local mcp_name="$1"

    if [[ ! -f "$CLAUDE_JSON" ]]; then
      echo -e "${RED}No .claude.json found.${RESET}"
      return 1
    fi

    python3 - "$CLAUDE_JSON" "$mcp_name" <<'PYEOF'
import json
import sys

path = sys.argv[1]
mcp_name = sys.argv[2]

with open(path) as f:
    data = json.load(f)

deleted = False
projects = data.get("projects", {})

for project_path, project_data in projects.items():
    mcp_servers = project_data.get("mcpServers", {})
    if mcp_name in mcp_servers:
        del mcp_servers[mcp_name]
        print(f"Deleted '{mcp_name}' from {project_path}")
        deleted = True

if deleted:
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print("Done.")
else:
    print(f"MCP server '{mcp_name}' not found.")
    sys.exit(1)

PYEOF
  }

  delete_all() {
    if [[ ! -f "$CLAUDE_JSON" ]]; then
      echo -e "${YELLOW}No .claude.json found.${RESET}"
      return
    fi

    echo -e "${YELLOW}This will delete all local MCP servers.${RESET}"
    read -rp "Continue? [y/N]: " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      python3 - "$CLAUDE_JSON" <<'PYEOF'
import json
import sys

path = sys.argv[1]

with open(path) as f:
    data = json.load(f)

count = 0
projects = data.get("projects", {})

for project_path, project_data in projects.items():
    mcp_servers = project_data.get("mcpServers", {})
    if mcp_servers:
        count += len(mcp_servers)
        project_data["mcpServers"] = {}

if count > 0:
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Deleted {count} MCP server(s).")
else:
    print("No MCP servers to delete.")

PYEOF
    else
      echo "Cancelled."
    fi
  }

  if [[ $# -eq 0 ]]; then
    mcp_usage
    return 0
  fi

  case "$1" in
    -l|--list)
      list_mcps
      ;;
    -d|--delete)
      if [[ -z "${2:-}" ]]; then
        echo -e "${RED}Error: MCP server name required.${RESET}"
        echo "Use: cli mcp -d <name> or cli mcp --delete <name>"
        return 1
      fi
      delete_mcp "$2"
      ;;
    -a|--all)
      delete_all
      ;;
    -h|--help)
      mcp_usage
      ;;
    *)
      echo -e "${RED}Unknown option: $1${RESET}"
      mcp_usage
      return 1
      ;;
  esac
}

# ─── Plugin Subcommand ───────────────────────────────────────────────────────
run_delete_plugin() {
  PLUGIN_DIR="$HOME/.claude/plugins"
  CONFIG_FILE="$PLUGIN_DIR/installed_plugins.json"
  CACHE_DIR="$PLUGIN_DIR/cache"

  plugin_usage() {
    echo "Usage: cli plugin [options]"
    echo ""
    echo "Options:"
    echo "  -d, --delete <name>  Delete a specific plugin"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  cli plugin -d claude-hud"
    echo "  cli plugin -d code-simplifier"
    echo ""
    echo "Note: Use this when 'claude plugin remove' fails due to bugs."
  }

  if [[ $# -eq 0 ]]; then
    plugin_usage
    return 0
  fi

  case "$1" in
    -d|--delete)
      if [[ -z "${2:-}" ]]; then
        echo -e "${RED}Error: Plugin name required.${RESET}"
        echo "Use: cli plugin -d <name> or cli plugin --delete <name>"
        return 1
      fi
      ;;
    -h|--help)
      plugin_usage
      return 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${RESET}"
      plugin_usage
      return 1
      ;;
  esac

  PLUGIN_NAME="$2"
  echo -e "${YELLOW}Forcefully removing plugin: $PLUGIN_NAME${NC}"

  # Handle both formats: "claude-hud" and "claude-hud@claude-hud"
  PLUGIN_KEY=$(echo "$PLUGIN_NAME" | sed 's/@.*$//')
  if [[ "$PLUGIN_NAME" == *"@"* ]]; then
    PLUGIN_FULL="$PLUGIN_NAME"
  else
    PLUGIN_FULL="$PLUGIN_NAME@$PLUGIN_NAME"
  fi

  # Find and remove plugin directory
  PLUGIN_PATH=""
  if [[ -d "$PLUGIN_DIR/$PLUGIN_NAME" ]]; then
    PLUGIN_PATH="$PLUGIN_DIR/$PLUGIN_NAME"
  elif [[ -d "$PLUGIN_DIR/${PLUGIN_FULL}" ]]; then
    PLUGIN_PATH="$PLUGIN_DIR/${PLUGIN_FULL}"
  fi

  if [[ -n "$PLUGIN_PATH" ]]; then
    echo "Removing plugin directory: $PLUGIN_PATH"
    rm -rf "$PLUGIN_PATH"
    echo -e "${GREEN}✓ Directory removed${NC}"
  else
    echo -e "${YELLOW}⚠ Plugin directory not found${NC}"
  fi

  # Remove from cache
  if [[ -d "$CACHE_DIR" ]]; then
    for dir in "$CACHE_DIR"/*; do
      if [[ -d "$dir/$PLUGIN_NAME" ]] || [[ -d "$dir/${PLUGIN_FULL}" ]]; then
        CACHE_PATH="$dir/$PLUGIN_NAME"
        [[ -d "$dir/${PLUGIN_FULL}" ]] && CACHE_PATH="$dir/${PLUGIN_FULL}"
        echo "Removing from cache: $CACHE_PATH"
        rm -rf "$CACHE_PATH"
        echo -e "${GREEN}✓ Cache removed${NC}"
        break
      fi
    done
  fi

  # Update config file
  if [[ -f "$CONFIG_FILE" ]]; then
    if grep -q "\"$PLUGIN_FULL\"" "$CONFIG_FILE"; then
      echo "Updating $CONFIG_FILE..."
      python3 - "$CONFIG_FILE" "$PLUGIN_FULL" <<'PYEOF'
import json
import sys

path = sys.argv[1]
plugin_full = sys.argv[2]

with open(path, 'r') as f:
    data = json.load(f)

if plugin_full in data.get('plugins', {}):
    del data['plugins'][plugin_full]
    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print('✓ Config updated')
else:
    print('⚠ Plugin not found in config')
PYEOF
    else
      echo -e "${YELLOW}⚠ Plugin not found in config file${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ Config file not found${NC}"
  fi

  # Update settings.json
  SETTINGS_FILE="$HOME/.claude/settings.json"
  if [[ -f "$SETTINGS_FILE" ]]; then
    echo "Updating $SETTINGS_FILE..."
    python3 - "$SETTINGS_FILE" "$PLUGIN_NAME" "$PLUGIN_KEY" "$PLUGIN_FULL" <<'PYEOF'
import json
import sys

settings_path = sys.argv[1]
plugin_name = sys.argv[2]
plugin_key = sys.argv[3]
plugin_full = sys.argv[4]

with open(settings_path, 'r') as f:
    data = json.load(f)

modified = False

# Remove from enabledPlugins
if 'enabledPlugins' in data:
    plugins_to_remove = [plugin_name, plugin_key, plugin_full]
    for p in plugins_to_remove:
        if p in data['enabledPlugins']:
            del data['enabledPlugins'][p]
            modified = True
            print(f'✓ Removed from enabledPlugins: {p}')

# Remove from extraKnownMarketplaces
if 'extraKnownMarketplaces' in data:
    marketplaces_to_remove = [plugin_name, plugin_key]
    for m in marketplaces_to_remove:
        if m in data['extraKnownMarketplaces']:
            del data['extraKnownMarketplaces'][m]
            modified = True
            print(f'✓ Removed from extraKnownMarketplaces: {m}')

# Check if statusLine references the plugin
if 'statusLine' in data and 'command' in data['statusLine']:
    status_cmd = data['statusLine']['command']
    if plugin_name in status_cmd or plugin_key in status_cmd:
        del data['statusLine']
        modified = True
        print('✓ Removed statusLine (plugin reference found)')

if modified:
    with open(settings_path, 'w') as f:
        json.dump(data, f, indent=2)
    print('✓ settings.json updated')
else:
    print('⚠ No changes needed in settings.json')
PYEOF
  else
    echo -e "${YELLOW}⚠ settings.json not found${NC}"
  fi

  echo -e "${GREEN}Plugin '$PLUGIN_NAME' has been forcefully removed${NC}"
}

# ─── Main: Handle arguments ─────────────────────────────────────────────────
RESUME_MODE=0
RESUME_SESSION=""
CONF_MODE=0

# Handle subcommands first
if [[ "${1:-}" == "uninstall" ]]; then
  shift
  run_uninstall "$@"
  exit $?
elif [[ "${1:-}" == "mcp" ]]; then
  shift
  run_mcp "$@"
  exit $?
elif [[ "${1:-}" == "plugin" ]]; then
  shift
  run_delete_plugin "$@"
  exit $?
elif [[ "${1:-}" == "resume" ]]; then
  RESUME_MODE=1
  RESUME_SESSION="${2:-}"
elif [[ "${1:-}" == "update" ]]; then
  check_update
  exit $?
elif [[ "${1:-}" == "config" ]]; then
  CONF_MODE=1
fi

if [[ "${1:-}" == "-u" ]] || [[ "${1:-}" == "--update" ]]; then
  check_update
  exit $?
elif [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  echo ""
  echo -e "${BOLD}Claude Code Launcher v${VERSION} (Ubuntu/Linux)${RESET}"
  echo ""
  echo "Usage:"
  echo -e "  ${GREEN}cli${RESET}                # Quick launch with saved configuration"
  echo -e "  ${GREEN}cli -r${RESET}            # Resume last session (interactive picker)"
  echo -e "  ${GREEN}cli -r [id]${RESET}       # Resume specific session by ID"
  echo -e "  ${GREEN}cli -c${RESET}            # Interactive configuration"
  echo -e "  ${GREEN}cli -u${RESET}            # Check for updates"
  echo -e "  ${GREEN}cli -h${RESET}            # Show this help message"
  echo ""
  echo "Options:"
  echo "  -r, --resume [id]  Resume a session (optional: session ID)"
  echo "  -c                 Show interactive configuration menu"
  echo "  -u, --update       Check for updates and install if available"
  echo "  -h, --help         Show this help message"
  echo ""
  echo "Subcommands:"
  echo "  uninstall           Uninstall claude-launcher and optionally remove config"
  echo "  mcp [options]       Manage MCP servers:"
  echo "                        -l, --list     List all MCP servers"
  echo "                        -d, --delete   Delete a specific MCP server"
  echo "                        -a, --all      Delete all MCP servers"
  echo "  plugin -d <name>    Forcefully delete a plugin"
  echo "  resume [id]         Resume a session (same as -r)"
  echo "  update              Check for updates (same as -u)"
  echo "  config              Interactive configuration (same as -c)"
  echo ""
  echo "Examples:"
  echo "  cli                 # Launch with last used provider/model"
  echo "  cli -r              # Resume last session"
  echo "  cli resume          # Resume last session (alternative)"
  echo "  cli -c              # Change provider/model/API key"
  echo "  cli config          # Change provider/model/API key (alternative)"
  echo "  cli -u              # Check for updates"
  echo "  cli update          # Check for updates (alternative)"
  echo "  cli uninstall       # Uninstall claude-launcher"
  echo "  cli mcp -l          # List MCP servers"
  echo "  cli mcp -d brave    # Delete brave MCP server"
  echo "  cli mcp -a          # Delete all MCP servers"
  echo "  cli plugin -d hud    # Delete a plugin"
  echo ""
  exit 0
elif [[ "${1:-}" == "-r" ]] || [[ "${1:-}" == "--resume" ]]; then
  RESUME_MODE=1
  RESUME_SESSION="${2:-}"
elif [[ "${1:-}" == "--resume" ]] && [[ -n "${2:-}" ]]; then
  RESUME_MODE=1
  RESUME_SESSION="${2:-}"
elif [[ "${1:-}" == "-c" ]]; then
  # Run interactive configuration
  CONF_MODE=1
elif [[ -n "${1:-}" ]] && [[ "$RESUME_MODE" -eq 0 && "$CONF_MODE" -eq 0 ]]; then
  # Unknown argument, show help
  echo "Usage: $0           # Launch with saved configuration"
  echo "       $0 -r [id]   # Resume last session (optional: session ID)"
  echo "       $0 -c         # Show interactive configuration"
  echo "       $0 -h         # Show help message"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
#  Load saved defaults
# ─────────────────────────────────────────────────────────────────────────────
load_defaults

# Check if config exists - auto-switch to interactive if no config
if [[ "$CONF_MODE" -eq 0 && -z "$DEFAULT_PLAN" ]]; then
  echo -e "${YELLOW}No saved configuration found.${RESET}"
  echo "Starting interactive configuration..."
  CONF_MODE=1
fi

# ─── In config mode: check dependencies & Claude Code ─────────────────────────
if [[ "$CONF_MODE" -eq 1 ]]; then
  check_dependencies
  check_claude_code
fi

# ─── Resume mode: restore last session ─────────────────────────────────────────
if [[ "$RESUME_MODE" -eq 1 ]]; then
  # Load config first to get provider settings
  load_defaults

  # Determine project directory
  PROJECT_DIR="${LAST_PROJECT_DIR:-$(pwd)}"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo -e "${YELLOW}Project directory not found:${RESET} $PROJECT_DIR"
    echo "Using current directory instead."
    PROJECT_DIR="$(pwd)"
  fi

  cd "$PROJECT_DIR"

  # Build resume command
  RESUME_ARGS=()
  if [[ -n "$RESUME_SESSION" ]]; then
    RESUME_ARGS+=("--resume" "$RESUME_SESSION")
  else
    RESUME_ARGS+=("--resume")
  fi

  # Apply saved provider settings (same as quick_launch but for resume)
  AGENT_TEAMS_CHOICE="${DEFAULT_AGENT_TEAMS:-2}"
  BRAVE_SEARCH_CHOICE="${DEFAULT_BRAVE_SEARCH:-2}"
  TAVILY_SEARCH_CHOICE="${DEFAULT_TAVILY_SEARCH:-2}"

  case "$DEFAULT_PLAN" in
    1)  # Anthropic
      PROVIDER="anthropic"
      restore_settings
      case "${DEFAULT_MC_1:-2}" in
        1) SELECTED_MODEL="claude-opus-4-6" ;;
        2) SELECTED_MODEL="claude-sonnet-4-6" ;;
        3) SELECTED_MODEL="claude-haiku-4-5-20251001" ;;
        *) SELECTED_MODEL="claude-sonnet-4-6" ;;
      esac
      ;;
    2)  # MiniMaxi
      PROVIDER="minimaxi"
      if [[ -z "${MINIMAX_API_KEY:-}" ]]; then
        echo -e "${RED}Error: MiniMax API key not found.${RESET}"
        echo "Run with -c to configure."
        exit 1
      fi
      case "${DEFAULT_MC_2:-1}" in
        1) SELECTED_MODEL="MiniMax-M2.7" ;;
        2) SELECTED_MODEL="MiniMax-M2.7-highspeed" ;;
        3) SELECTED_MODEL="MiniMax-M2.5" ;;
        4) SELECTED_MODEL="MiniMax-M2.5-highspeed" ;;
        5) SELECTED_MODEL="MiniMax-M2.1" ;;
        6) SELECTED_MODEL="MiniMax-M2" ;;
        *) SELECTED_MODEL="MiniMax-M2.7" ;;
      esac
      write_minimax_settings "$MINIMAX_API_KEY" "$SELECTED_MODEL" "$AGENT_TEAMS_CHOICE"
      ensure_onboarding
      export ANTHROPIC_BASE_URL="https://api.minimaxi.com/anthropic"
      export ANTHROPIC_AUTH_TOKEN="$MINIMAX_API_KEY"
      export API_TIMEOUT_MS="3000000"
      export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="1"
      export ANTHROPIC_MODEL="$SELECTED_MODEL"
      export ANTHROPIC_SMALL_FAST_MODEL="$SELECTED_MODEL"
      export ANTHROPIC_DEFAULT_SONNET_MODEL="$SELECTED_MODEL"
      export ANTHROPIC_DEFAULT_OPUS_MODEL="$SELECTED_MODEL"
      export ANTHROPIC_DEFAULT_HAIKU_MODEL="$SELECTED_MODEL"
      ;;
    3)  # Bailian
      PROVIDER="bailian"
      if [[ -z "${DASHSCOPE_API_KEY:-}" ]]; then
        echo -e "${RED}Error: DashScope API key not found.${RESET}"
        echo "Run with -c to configure."
        exit 1
      fi
      case "${DEFAULT_MC_3:-1}" in
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
        *) SELECTED_MODEL="qwen3-max-2026-01-23" ;;
      esac
      write_bailian_settings "$DASHSCOPE_API_KEY" "$SELECTED_MODEL" "$AGENT_TEAMS_CHOICE"
      ensure_onboarding
      export ANTHROPIC_BASE_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic"
      export ANTHROPIC_AUTH_TOKEN="$DASHSCOPE_API_KEY"
      ;;
  esac

  if [[ "$AGENT_TEAMS_CHOICE" == "1" ]]; then
    export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"
  fi

  PROVIDER_NAMES=("" "Claude Code" "MiniMaxi" "Bailian")
  PROVIDER_LABEL="${PROVIDER_NAMES[$DEFAULT_PLAN]}"

  echo -e "${CYAN}${BOLD}  Resuming Claude Code Session${RESET}"
  echo -e "  ${DIM}Provider:${RESET} ${YELLOW}${PROVIDER_LABEL}${RESET}"
  echo -e "  ${DIM}Model   :${RESET} ${BLUE}${SELECTED_MODEL}${RESET}"
  echo -e "  ${DIM}Project :${RESET} ${DIM}${PROJECT_DIR}${RESET}"
  if [[ "$AGENT_TEAMS_CHOICE" == "1" ]]; then
    echo -e "  ${DIM}Agent   :${RESET} ${GREEN}Enabled${RESET}"
  fi
  echo ""

  exec claude --model "opus[1m]" --permission-mode bypassPermissions "${RESUME_ARGS[@]}"
fi

# Quick launch if no conf mode
if [[ "$CONF_MODE" -eq 0 ]]; then
  quick_launch
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 1 — Select Provider (interactive)
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
AGENT_TEAMS_CHOICE="${DEFAULT_AGENT_TEAMS:-2}"  # Default to disabled
BRAVE_SEARCH_CHOICE="${DEFAULT_BRAVE_SEARCH:-2}"  # Default to disabled
TAVILY_SEARCH_CHOICE="${DEFAULT_TAVILY_SEARCH:-2}" # Default to disabled

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
    write_anthropic_settings "$SELECTED_MODEL"
    ;;

  # ── MiniMaxi (2) ─────────────────────────────────────────────────────────
  2)
    PROVIDER="minimaxi"
    BASE_URL="https://api.minimaxi.com/anthropic"
    API_KEY_VAR="MINIMAX_API_KEY"
    # Allow user to update key even if one is saved
    if [[ -n "${MINIMAX_API_KEY:-}" ]]; then
      echo -e "  ${DIM}Current API key is saved.${RESET}"
      print_menu "MiniMax API Key:" \
        "Use existing key" \
        "Enter new key"
      key_choice=$(pick "Key" 2 "1")
      if [[ "$key_choice" == "2" ]]; then
        unset MINIMAX_API_KEY
      fi
    fi
    require_key "$API_KEY_VAR" "MiniMax"

    print_menu "Select MiniMaxi Model:" \
      "─────────────────────────────────────────" \
      "Recommended Model:" \
      "  MiniMax-M2.7           — Latest flagship, SOTA coding, reasoning & agents" \
      "  MiniMax-M2.7-highspeed  — Same as M2.7, faster inference" \
      "─────────────────────────────────────────" \
      "More Models:" \
      "  MiniMax-M2.5            — Previous flagship, strong coding and reasoning" \
      "  MiniMax-M2.5-highspeed  — Same as M2.5, faster inference" \
      "  MiniMax-M2.1            — 230B parameters, multilingual and code" \
      "  MiniMax-M2              — 200k context, agentic calls"
    MC=$(pick "Model" 6 "$DEFAULT_MC_2")
    DEFAULT_MC_2=$MC
    case "$MC" in
      1) SELECTED_MODEL="MiniMax-M2.7" ;;
      2) SELECTED_MODEL="MiniMax-M2.7-highspeed" ;;
      3) SELECTED_MODEL="MiniMax-M2.5" ;;
      4) SELECTED_MODEL="MiniMax-M2.5-highspeed" ;;
      5) SELECTED_MODEL="MiniMax-M2.1" ;;
      6) SELECTED_MODEL="MiniMax-M2" ;;
    esac

    write_minimax_settings "${MINIMAX_API_KEY}" "${SELECTED_MODEL}" "${AGENT_TEAMS_CHOICE}"
    ensure_onboarding

    EXTRA_ARGS+=(
      --append-system-prompt "You are using the MiniMax API. Leverage MiniMax model strengths for text generation, reasoning, and code tasks."
    ) ;;

  # ─── Bailian / DashScope (3) ───────────────────────────────────────────────
  3)
    PROVIDER="bailian"
    BASE_URL="https://coding.dashscope.aliyuncs.com/apps/anthropic"
    API_KEY_VAR="DASHSCOPE_API_KEY"
    restore_settings
    # Allow user to update key even if one is saved
    if [[ -n "${DASHSCOPE_API_KEY:-}" ]]; then
      echo -e "  ${DIM}Current API key is saved.${RESET}"
      print_menu "DashScope API Key:" \
        "Use existing key" \
        "Enter new key"
      key_choice=$(pick "Key" 2 "1")
      if [[ "$key_choice" == "2" ]]; then
        unset DASHSCOPE_API_KEY
      fi
    fi
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
    write_bailian_settings "${!API_KEY_VAR}" "$SELECTED_MODEL" "${AGENT_TEAMS_CHOICE}"
    ensure_onboarding

    EXTRA_ARGS+=(
      --append-system-prompt "You are using Alibaba Bailian (DashScope) with Qwen models. Leverage Qwen's strengths in multilingual tasks, long-context understanding, and coding."
    ) ;;

esac

# ─── Step 2.5 — Agent Teams Option ───────────────────────────────────────────
echo ""
print_menu "Enable Agent Teams?" \
  "[Yes] Enable Agent Teams  — Coordinate multiple Claude instances working together" \
  "[No]  Disable (default)   — Standard single session"
AGENT_TEAMS_CHOICE=$(pick "Agent Teams" 2 "$DEFAULT_AGENT_TEAMS")

# ─── Step 2.6 — Claude-HUD Option ─────────────────────────────────────────────
echo ""
print_menu "Install Claude-HUD?" \
  "[Yes] Install (default)   — Install claude-hud plugin with all features" \
  "[No]  Skip                — Do not install claude-hud"
CLAUDE_HUD_CHOICE=$(pick "Claude-HUD" 2 "$DEFAULT_CLAUDE_HUD")

# Install or skip claude-hud based on user choice
if [[ "$CLAUDE_HUD_CHOICE" == "1" ]]; then
  check_claude_hud
fi

# ─── Step 2.7 — Brave Search MCP Option ────────────────────────────────────────
echo ""
print_menu "Install Brave Search MCP?" \
  "[Yes] Enable  — Enable Brave Search (requires API key, needs VPN)" \
  "[No]  Disable — Skip Brave Search"
BRAVE_SEARCH_CHOICE=$(pick "Brave Search" 2 "${DEFAULT_BRAVE_SEARCH}")

# Ask for API key if enabling Brave Search
if [[ "$BRAVE_SEARCH_CHOICE" == "1" ]]; then
  has_brave_key=0
  if [[ -n "${BRAVE_API_KEY:-}" ]]; then
    echo -e "  ${DIM}Current API key is saved.${RESET}"
    print_menu "Brave Search Key:" \
      "Use existing key" \
      "Enter new key"
    key_choice=$(pick "Key" 2 "1")
    if [[ "$key_choice" == "2" ]]; then
      has_brave_key=0
    else
      has_brave_key=1
    fi
  fi

  if [[ $has_brave_key -eq 0 ]]; then
    read -rsp "  Enter Brave Search API key: " BRAVE_API_KEY
    echo ""
    if [[ -z "$BRAVE_API_KEY" ]]; then
      echo -e "${YELLOW}No API key provided, skipping Brave Search.${RESET}"
      BRAVE_SEARCH_CHOICE="2"
    fi
  fi

  if [[ "$BRAVE_SEARCH_CHOICE" == "1" ]]; then
    configure_brave_search "$BRAVE_API_KEY"
  fi
fi

# ─── Step 2.8 — Tavily Search MCP Option ────────────────────────────────────────
echo ""
print_menu "Install Tavily Search MCP?" \
  "[Yes] Enable  — Enable Tavily Search for web search (requires API key)" \
  "[No]  Disable — Skip Tavily Search"
TAVILY_SEARCH_CHOICE=$(pick "Tavily Search" 2 "${DEFAULT_TAVILY_SEARCH}")

# Ask for API key if enabling Tavily Search
if [[ "$TAVILY_SEARCH_CHOICE" == "1" ]]; then
  has_tavily_key=0
  if [[ -n "${TAVILY_API_KEY:-}" ]]; then
    echo -e "  ${DIM}Current API key is saved.${RESET}"
    print_menu "Tavily Search Key:" \
      "Use existing key" \
      "Enter new key"
    key_choice=$(pick "Key" 2 "1")
    if [[ "$key_choice" == "2" ]]; then
      has_tavily_key=0
    else
      has_tavily_key=1
    fi
  else
    has_tavily_key=0
  fi

  if [[ $has_tavily_key -eq 0 ]]; then
    read -rsp "  Enter Tavily Search API key (starts with tvly-): " TAVILY_API_KEY
    echo ""
    if [[ -z "$TAVILY_API_KEY" ]]; then
      echo -e "${YELLOW}No API key provided, skipping Tavily Search.${RESET}"
      TAVILY_SEARCH_CHOICE="2"
    fi
  fi

  if [[ "$TAVILY_SEARCH_CHOICE" == "1" ]]; then
    configure_tavily_search "$TAVILY_API_KEY"
  fi
fi

# Always update MCP permissions
update_mcp_permissions

# ─── Save choices for next run ────────────────────────────────────────────────
save_defaults

# ─────────────────────────────────────────────────────────────────────────────
#  STEP 3 — Apply provider env overrides
# ─────────────────────────────────────────────────────────────────────────────
if [[ "$PROVIDER" != "anthropic" ]]; then
  export ANTHROPIC_BASE_URL="$BASE_URL"
  export ANTHROPIC_AUTH_TOKEN="${!API_KEY_VAR}"
fi

# Agent Teams support for all providers
if [[ "$AGENT_TEAMS_CHOICE" == "1" ]]; then
  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS="1"
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

# Save project directory for resume
LAST_PROJECT_DIR="$(pwd)"
save_defaults

# ─── Summary & Launch ────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}  Starting Claude Code${RESET}"
echo -e "  ${DIM}Provider:${RESET} ${YELLOW}${PROVIDER_LABEL}${RESET}"
echo -e "  ${DIM}Model   :${RESET} ${BLUE}${SELECTED_MODEL}${RESET}"
[[ -n "$BASE_URL" ]] && echo -e "  ${DIM}Endpoint:${RESET} ${DIM}${BASE_URL}${RESET}"
if [[ "$AGENT_TEAMS_CHOICE" == "1" ]]; then
  echo -e "  ${DIM}Agent   :${RESET} ${GREEN}Enabled${RESET}"
fi
echo ""

exec claude --model "opus[1m]" --permission-mode bypassPermissions "${EXTRA_ARGS[@]}"
