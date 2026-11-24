# Dynatrace MCP Connection Scripts

Quick setup for connecting Claude Desktop or an HTTP MCP client to any Dynatrace platform tenant.

## Prerequisites

- Node.js 24 or later
- Bash
- A Dynatrace platform URL, such as `https://abc12345.apps.dynatrace.com`

## Quick setup

Clone the repository and enter the directory:

```bash
git clone https://github.com/LawrenceBarratt90/MCPConnectionScript-Any_DTTenant-Remote.git
cd MCPConnectionScript-Any_DTTenant-Remote
```

Make the setup script executable:

```bash
chmod +x deploy-dynatrace-mcp.sh
```

### Claude Desktop (stdio)

Set the tenant URL and run the setup:

```bash
export DT_ENVIRONMENT="https://<tenant-id>.apps.dynatrace.com"
./deploy-dynatrace-mcp.sh
```

Fully quit and restart Claude Desktop after the script completes.

### Shared HTTP server

Set the tenant URL and start the server:

```bash
export DT_ENVIRONMENT="https://<tenant-id>.apps.dynatrace.com"
./deploy-dynatrace-mcp.sh http
```

The script prints the HTTP URL and bearer token. The default listener is:

```text
http://127.0.0.1:3000
```

For VS Code, copy `.vscode/mcp.json` into an open workspace, then enter the bearer token when prompted.

### Optional platform token

For unattended authentication, set a Dynatrace platform token before setup:

```bash
export DT_PLATFORM_TOKEN="<platform-token>"
```

With no platform token, the MCP server opens a browser OAuth login flow.

## Stop the HTTP server

```bash
kill "$(cat "$HOME/.dynatrace-mcp/server.pid")"
```

Keep the HTTP listener behind TLS and a trusted network boundary before exposing it beyond localhost.
