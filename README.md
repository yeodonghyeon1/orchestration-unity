# orchestration-unity

A Claude Code plugin that runs Unity game development tasks as a **10-agent consensus team**. One team lead orchestrates two planners, two designers, two developers, two recorders, and one tester through an eight-phase workflow with plan/accept voting, role-pair peer review, playtesting, and AI-readable documentation output.

- **Skill name:** `unity-orchestration`
- **Slash command:** `/unity-orchestration "<task description>"`
- **Requires:** Claude Code, Superpowers plugin, [`unity-mcp`](https://github.com/CoplayDev/unity-mcp) MCP server, a Unity project

## Install

In Claude Code, from any directory:

```
/plugin marketplace add yeodonghyeon1/orchestration-unity
/plugin install unity-orchestration@orchestration-unity
```

That's it. Restart Claude Code if prompted, then `cd` into your Unity project and run:

```
/unity-orchestration "add an enemy patrol system"
```

## What it does

For any non-trivial Unity task, the plugin spins up ten agents that:

1. **Explore** the codebase in parallel, each from their role's perspective.
2. **Distribute** sub-tasks through the team lead and **vote** on the plan (≥6/10 to pass).
3. **Execute** sub-tasks with role-pair peer review (A/B agents must agree before handoff).
4. **Playtest** — the tester plays through implemented features via `unity-mcp`, reporting bugs from a gamer's perspective.
5. **Cross-review** each other's output and cast an **accept vote** (≥6/10 to ship).
6. **Promote** curated session artifacts into a general, AI-readable `docs/` tree that survives the session.

See [`docs/architecture.md`](docs/architecture.md) for component diagrams and the [design spec](docs/superpowers/specs/2026-04-11-unity-orchestration-design.md) for the full rationale.

## Team composition

| Count | Role | What they produce | Unity MCP access |
|---|---|---|---|
| 1 | `team-lead` | Vote tally, distribution, MCP lock, deadlock intervention | no |
| 2 | `planner-a/b` | Game systems, balancing, acceptance criteria | no |
| 2 | `designer-a/b` | Scenes, prefabs, UI, art direction | yes (with lock) |
| 2 | `dev-a/b` | C# scripts, tests, data-asset implementations | yes (with lock) |
| 2 | `recorder-a/b` | Transcript, `docs/` tree, quality review | no |
| 1 | `tester` | Playtest findings, gamer-perspective QA, bug reports | yes (with lock) |

Pairs (A/B) critique each other internally on small sub-tasks. The tester operates solo — no pair, no abstain obligation. On big-task completion, all ten cross-review artifacts outside their own pair (anti-collusion rule).

## Documentation output

Every big task produces a curated bundle under `docs/tasks/<id>/` — summary, consultation transcript, vote records, and an outcome list of files changed. The broader `docs/` tree follows a strict engine-independent format documented in [`skills/unity-orchestration/docs-tree-spec.md`](skills/unity-orchestration/docs-tree-spec.md): YAML frontmatter on every file, path-ID canonical references, `_meta/index.json` as the machine-readable landing page. `game/`, `design/`, `decisions/`, `tasks/`, and `_meta/` are engine-agnostic; Unity-specific vocabulary is confined to `docs/tech/`.

## Docs

- [Getting started](docs/getting-started.md) — prerequisites, first run, what to watch
- [Architecture](docs/architecture.md) — components and runtime model
- [Troubleshooting](docs/troubleshooting.md) — common failure modes and fixes
- [Design spec](docs/superpowers/specs/2026-04-11-unity-orchestration-design.md) — full v1 design rationale
- [Implementation plan](docs/superpowers/plans/2026-04-11-unity-orchestration.md) — 12-task build breakdown

## Status

**v0.2.0** — added tester agent and playtest phase. Structure-check and script unit tests pass; dry-run scenarios are a manual checklist. Known limitations (session resume, multi-session parallelism, non-Unity engines, automated scenario tests) are listed in [`CHANGELOG.md`](CHANGELOG.md).

Bug reports and PRs welcome at [github.com/yeodonghyeon1/orchestration-unity/issues](https://github.com/yeodonghyeon1/orchestration-unity/issues).

## License

MIT — see [`LICENSE`](LICENSE).
