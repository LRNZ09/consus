# AGENTS.md

These settings are applied to all projects.

## Tooling: prefer MCP over CLI

- When a connected MCP server can perform a task, **prefer it over the equivalent CLI**. Fall back to a CLI only when no MCP is available, or the MCP can't do that specific operation.
- Applies to **all** tooling, not just the examples below (GitHub: a GitHub MCP over `gh`; etc.).

## GitHub

- **Prefer a GitHub MCP** when one is connected; otherwise use the CLI `gh` (already authenticated).
