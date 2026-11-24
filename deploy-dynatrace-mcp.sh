#!/usr/bin/env bash
# Deploy the Dynatrace MCP server (dynatrace-oss/dynatrace-mcp) start to finish.
#
# Usage:
#   ./deploy-dynatrace-mcp.sh          # local: registers the server in Claude Desktop (stdio)
#   ./deploy-dynatrace-mcp.sh http     # shared: starts an HTTP server with a bearer token
#
# Note: the upstream repo is deprecated (final release 2.1.2) but still works.

set -euo pipefail

MODE="${1:-stdio}"
PKG="@dynatrace-oss/dynatrace-mcp-server@latest"
CONF_DIR="$HOME/.dynatrace-mcp"
ENV_FILE="$CONF_DIR/env"
PORT="${PORT:-3000}"
HOST="${HOST:-127.0.0.1}"   # use 0.0.0.0 inside containers / for remote access

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# 1. Node.js 24+ -------------------------------------------------------------
log "Checking Node.js (v24+ required)"
node_major() { node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/' || echo 0; }

if ! command -v node >/dev/null 2>&1 || [ "$(node_major)" -lt 24 ]; then
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
      die "Node 24+ not found. Install it first (PowerShell: winget install OpenJS.NodeJS), then open a NEW Git Bash window and re-run." ;;
  esac
  echo "Node 24+ not found. Installing via nvm..."
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  fi
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install 24
  nvm use 24
fi
[ "$(node_major)" -ge 24 ] || die "Node 24+ is required, found $(node -v)"
echo "Using Node $(node -v)"

# 2. Collect settings --------------------------------------------------------
log "Configuring"
mkdir -p "$CONF_DIR" && chmod 700 "$CONF_DIR"

DT_ENVIRONMENT="${DT_ENVIRONMENT:-}"
if [ -z "$DT_ENVIRONMENT" ]; then
  read -r -p "Dynatrace platform URL (e.g. https://abc12345.apps.dynatrace.com): " DT_ENVIRONMENT
fi
DT_ENVIRONMENT="${DT_ENVIRONMENT%/}"
case "$DT_ENVIRONMENT" in
  https://*) ;;
  *) die "URL must start with https://" ;;
esac
case "$DT_ENVIRONMENT" in
  *.live.dynatrace.com*) die "Use the platform URL (*.apps.dynatrace.com), not the classic live.dynatrace.com URL" ;;
esac

DT_PLATFORM_TOKEN="${DT_PLATFORM_TOKEN:-}"
if [ -z "$DT_PLATFORM_TOKEN" ] && [ -t 0 ]; then
  read -r -s -p "Platform token (optional, Enter = browser SSO login on first use): " DT_PLATFORM_TOKEN
  echo
fi

{
  echo "DT_ENVIRONMENT=$DT_ENVIRONMENT"
  [ -n "$DT_PLATFORM_TOKEN" ] && echo "DT_PLATFORM_TOKEN=$DT_PLATFORM_TOKEN"
  echo "DT_MCP_DISABLE_TELEMETRY=true"
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"
echo "Saved settings to $ENV_FILE"

# 3. Pre-fetch the package so first launch is fast ---------------------------
log "Downloading $PKG"
npx -y "$PKG" --help >/dev/null 2>&1 || die "Could not download the package (check network / npm registry access)"

# 4a. stdio mode: register in Claude Desktop ---------------------------------
register_claude_desktop() {
  case "$(uname -s)" in
    Darwin) CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
    Linux)  CFG="$HOME/.config/Claude/claude_desktop_config.json" ;;
    MINGW*|MSYS*|CYGWIN*)
      [ -n "${APPDATA:-}" ] || die "APPDATA is not set; cannot locate the Claude Desktop config"
      CFG="$APPDATA/Claude/claude_desktop_config.json" ;;
    *)      die "Unsupported OS ($(uname -s)). Use the manual config snippet from the README/chat." ;;
  esac
  mkdir -p "$(dirname "$CFG")"
  [ -f "$CFG" ] && cp "$CFG" "$CFG.bak" && echo "Backed up existing config to $CFG.bak"

  CFG="$CFG" PKG="$PKG" DT_ENVIRONMENT="$DT_ENVIRONMENT" DT_PLATFORM_TOKEN="$DT_PLATFORM_TOKEN" \
  node -e '
    const fs = require("fs");
    const p = process.env.CFG;
    let cfg = {};
    if (fs.existsSync(p)) { try { cfg = JSON.parse(fs.readFileSync(p, "utf8")); } catch { console.error("Existing config is not valid JSON; aborting."); process.exit(1); } }
    cfg.mcpServers = cfg.mcpServers || {};
    const env = { DT_ENVIRONMENT: process.env.DT_ENVIRONMENT };
    if (process.env.DT_PLATFORM_TOKEN) env.DT_PLATFORM_TOKEN = process.env.DT_PLATFORM_TOKEN;
    // On Windows, Claude Desktop needs cmd /c to launch npx (npx.cmd)
    const win = process.platform === "win32";
    cfg.mcpServers["dynatrace-mcp-server"] = win
      ? { command: "cmd", args: ["/c", "npx", "-y", process.env.PKG], env }
      : { command: "npx", args: ["-y", process.env.PKG], env };
    fs.writeFileSync(p, JSON.stringify(cfg, null, 2));
    console.log("Updated " + p);
  '
  log "Done. Fully quit and restart Claude Desktop, then ask: \"List my Dynatrace problems from the last 24h\""
}

# 4b. http mode: start a shared server ---------------------------------------
start_http() {
  MCP_BEARER_TOKEN="${MCP_BEARER_TOKEN:-$(openssl rand -base64 32)}"
  echo "MCP_BEARER_TOKEN=$MCP_BEARER_TOKEN" >> "$ENV_FILE"

  set -a; . "$ENV_FILE"; set +a
  nohup npx -y "$PKG" --http --host "$HOST" --port "$PORT" > "$CONF_DIR/server.log" 2>&1 &
  echo $! > "$CONF_DIR/server.pid"
  sleep 3
  kill -0 "$(cat "$CONF_DIR/server.pid")" 2>/dev/null || { cat "$CONF_DIR/server.log"; die "Server failed to start"; }

  log "Server running (pid $(cat "$CONF_DIR/server.pid")), logs: $CONF_DIR/server.log"
  cat <<EOF

Client config:
{
  "mcpServers": {
    "dynatrace-http": {
      "url": "http://$HOST:$PORT",
      "transport": "http",
      "headers": { "Authorization": "Bearer $MCP_BEARER_TOKEN" }
    }
  }
}

Stop with:  kill \$(cat $CONF_DIR/server.pid)
Put TLS (reverse proxy) in front before exposing beyond localhost.
EOF
}

case "$MODE" in
  stdio) register_claude_desktop ;;
  http)  start_http ;;
  *)     die "Unknown mode '$MODE' (use: stdio | http)" ;;
esac

cat <<'EOF'

Reminder: your platform token / OAuth client needs scopes such as app-engine:apps:run
plus the storage:*:read scopes for DQL. Add document/email/davis scopes only if you use those tools.
EOF