# orchestration-unity

A Claude Code plugin that runs Unity game development tasks as a 9-agent consensus team.

- **Skill name:** `unity-orchestration`
- **Slash command:** `/unity-orchestration "<task description>"`
- **Depends on:** Superpowers plugin, `unity-mcp` MCP server (upstream: `CoplayDev/unity-mcp`)

## What it does

For any non-trivial Unity task you throw at it, the plugin spins up a 9-agent team (1 team lead, 2 planners, 2 designers, 2 developers, 2 recorders) that:

1. Explores the codebase from each role's perspective in parallel.
2. Debates a task distribution and votes on it (≥5/9 to pass).
3. Executes sub-tasks with role-pair peer review.
4. Cross-reviews each other's output and votes again (≥5/9 to accept).
5. Promotes curated session artifacts into a general, AI-readable `docs/` tree.

## Docs

- [Getting started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Full design spec](docs/superpowers/specs/2026-04-11-unity-orchestration-design.md)

## License

MIT
