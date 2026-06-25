# LyricDrive Agents

This directory holds repo-local agent integrations used while working on LyricDrive.

## Hermes Agent

`hermes-agent/` is a git submodule pointing to:

`https://github.com/NousResearch/hermes-agent.git`

The root `.mcp.json` exposes it as an MCP server named `hermes-agent`.

From a fresh clone, initialize it with:

```powershell
git submodule update --init --recursive
```

MCP clients that read `.mcp.json` can start Hermes with:

```powershell
uv --directory .agents/hermes-agent run --extra mcp hermes mcp serve
```

Hermes runtime data is written to `.agents/hermes-home/`, which is intentionally ignored by git.
