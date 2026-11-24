---
name: dynatrace-mcp
description: Use the Dynatrace MCP server to query telemetry, logs, metrics, traces, problems, events, entities, and Davis data in the configured Dynatrace tenant.
---

# Dynatrace MCP

Use this skill when the user asks about Dynatrace observability data or wants to investigate an application or environment.

## Connection

- MCP server: `dynatrace-http`
- URL: `http://127.0.0.1:3000`
- Authentication: bearer token
- Tenant: supplied through `DT_ENVIRONMENT`

## Workflow

1. Clarify the time range, entity, service, environment, and requested metric when the request is ambiguous.
2. Use Dynatrace MCP tools to query entities and telemetry rather than guessing identifiers.
3. Prefer DQL for structured searches across logs, metrics, spans, events, and problems.
4. Keep queries scoped by tenant and time range.
5. Summarize findings, include relevant entity IDs, timestamps, and query evidence, and distinguish observations from hypotheses.
