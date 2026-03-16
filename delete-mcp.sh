#!/usr/bin/env bash
# delete-mcp.sh — Delete local MCP servers from Claude Code

set -euo pipefail

# ─── ANSI colors ────────────────────────────────────────────────────────────
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

CLAUDE_JSON="${HOME}/.claude.json"

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -l, --list     List all local MCP servers"
  echo "  -d, --delete   Delete a specific MCP server (interactive)"
  echo "  -a, --all      Delete all local MCP servers"
  echo "  -h, --help     Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 -l                    # List all MCP servers"
  echo "  $0 -d brave-search       # Delete brave-search MCP"
  echo "  $0 -a                    # Delete all MCP servers"
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

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

# Check projects
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
                # Mask API key in URL
                import re
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
    exit 1
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

# Main
if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

case "$1" in
  -l|--list)
    list_mcps
    ;;
  -d|--delete)
    if [[ -z "${2:-}" ]]; then
      echo -e "${RED}Error: MCP server name required.${RESET}"
      echo "Use: $0 -d <name> or $0 --delete <name>"
      exit 1
    fi
    delete_mcp "$2"
    ;;
  -a|--all)
    delete_all
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo -e "${RED}Unknown option: $1${RESET}"
    usage
    exit 1
    ;;
esac
