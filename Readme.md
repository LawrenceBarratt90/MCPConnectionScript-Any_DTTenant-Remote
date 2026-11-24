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

## Optional: add the official `dtctl` CLI

[`dtctl`](https://github.com/Dynatrace/dtctl) complements this MCP server with a
Dynatrace CLI for DQL, workflows, dashboards, and other platform resources. It
is a separate client and authenticates independently; installing it does not
replace or configure the MCP server.

On macOS or Linux, install the latest release:

```bash
curl -fsSL https://raw.githubusercontent.com/Dynatrace/dtctl/main/install.sh | sh
```

In the same shell where `DT_ENVIRONMENT` is set, sign in and verify access:

```bash
dtctl auth login --context default --environment "$DT_ENVIRONMENT"
dtctl doctor
dtctl query "fetch logs | limit 10"
```

To install the `dtctl` Agent Skill for a supported AI client:

```bash
dtctl skills install
```

The Agent Skill explains how to operate the CLI; this repository's
`dynatrace-mcp` skill describes its MCP connection. Use either or both according
to the task and the tools available in your client. See the upstream
[installation guide](https://github.com/Dynatrace/dtctl/blob/main/docs/INSTALLATION.md)
for Windows, Homebrew, and other install options.

Already using this MCP setup? This Bash command installs or upgrades `dtctl`,
then authenticates it against the tenant URL you provide and checks access:

```bash
export DT_ENVIRONMENT="https://<tenant-id>.apps.dynatrace.com"
curl -fsSL https://raw.githubusercontent.com/Dynatrace/dtctl/main/install.sh | sh &&
  dtctl auth login --context default --environment "$DT_ENVIRONMENT" &&
  dtctl doctor
```

Rerun the command later to upgrade `dtctl`; the installer installs the latest
release.

If `DT_ENVIRONMENT` is already set in your current Bash shell, use this shorter
command:

```bash
curl -fsSL https://raw.githubusercontent.com/Dynatrace/dtctl/main/install.sh | sh &&
dtctl auth login --context default --environment "$DT_ENVIRONMENT" &&
dtctl doctor
```

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
