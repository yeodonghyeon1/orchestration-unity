# orchestration-unity

A Claude Code plugin that drives Unity game development through a
**Notion-driven Superpowers pipeline**. Human designers write in Notion;
Claude mirrors to `notion_docs/`, refines into `develop_docs/`, and
implements via `unity-mcp` with full TDD and verification discipline.

- **Skill names:** `unity-orchestration`, `notion-sync`, `docs-refinement`
- **Slash commands:** `/unity-orchestration`, `/notion-sync`, `/docs-refinement`, `/docs-update`
- **Requires:** Claude Code, [Superpowers plugin](https://github.com/obra/superpowers-marketplace), Notion MCP, [unity-mcp](https://github.com/CoplayDev/unity-mcp), a Unity project

> Coming from v0.2.0 (10-agent consensus)? See `CHANGELOG.md` for breaking
> changes and run `bash scripts/migrate-v02-to-v1.sh` to migrate.

## Install

```
/plugin marketplace add yeodonghyeon1/orchestration-unity
/plugin install unity-orchestration@orchestration-unity
```

Restart Claude Code if prompted, then `cd` into your Unity project.

## First-time setup

1. Create three top-level pages in your Notion workspace: `개발`, `아트`, `기획` (see `docs/notion-schema-guide.md` for content conventions).
2. Run once: `bash scripts/init-workspace.sh .`
3. First sync: `/notion-sync` — confirms page → folder mappings.

## Daily workflows

### When Notion changes

```
/docs-update
```

Runs: sync → refine → commit → push to `sync/notion-YYYYMMDD-HHMM` branch.
Review the PR manually and merge.

### When developing a feature

```
/unity-orchestration "add enemy patrol system"
```

Runs the eleven-step Superpowers chain: brainstorming → plan → TDD execution → verification → code-derived develop_docs update → branch finishing.

## Architecture at a glance

```
Notion (개발 / 아트 / 기획)
    ↓ /notion-sync
notion_docs/  (1:1 raw mirror)
    ↓ /docs-refinement
develop_docs/  (refined, cross-referenced, living)
    ↓ /unity-orchestration <task>
Superpowers chain → Unity MCP → code + tests
    ↓ Step 10
develop_docs/tech/unity/**  (auto-updated with class signatures)
```

See `docs/architecture.md` for the full component diagram.

## Docs

- `docs/architecture.md` — architecture overview
- `docs/notion-schema-guide.md` — Notion content conventions
- `docs/superpowers/specs/2026-04-18-orchestration-unity-v1-design.md` — full technical spec
- `docs/archive/v0.2/` — historical v0.2.0 docs

## Status

**v1.0.0** — initial Notion-driven Superpowers release. Supersedes v0.2.0
consensus team entirely. See `CHANGELOG.md`.

Bug reports and PRs welcome at <https://github.com/yeodonghyeon1/orchestration-unity/issues>.

## License

MIT — see `LICENSE`.
