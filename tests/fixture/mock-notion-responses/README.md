# Mock Notion MCP Responses

These fixtures simulate responses from `mcp__claude_ai_Notion__notion-search`
and `mcp__claude_ai_Notion__notion-fetch` for offline testing of the sync
engine.

## Files

| File | Simulates |
|------|-----------|
| `page-list.json` | Response to `notion-search` with all top-level pages |
| `page-dev.json` | Response to `notion-fetch` for the 개발 page |
| `page-art.json` | Response to `notion-fetch` for the 아트 page |
| `page-plan.json` | Response to `notion-fetch` for the 기획 page |

## Usage

The integration test (`tests/integration/test-notion-sync.sh`) pipes these
files directly to `scripts/notion-hash.py` and the sync engine to verify
end-to-end behavior without hitting Notion.

## Adding new fixtures

When adding test cases, keep the page IDs stable (`uuid-dev`, `uuid-art`,
`uuid-plan`) so reverse-index tests across Slices A/B/C stay consistent.
