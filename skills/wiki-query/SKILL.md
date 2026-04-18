---
name: wiki-query
description: Use when the user asks a question about the project that should be answered from the llm_wiki. Reads docs/llm_wiki/index.md first to locate relevant pages, then reads those pages to compose a cited answer. Optionally files the answer back into docs/llm_wiki/explorations/.
---

# wiki-query

Answer a user question against the llm-wiki. Not a general-knowledge
question answerer — strictly wiki-grounded.

**Announce at start:** "I'm using the wiki-query skill to answer from llm_wiki."

## Pre-flight

1. `docs/llm_wiki/index.md` exists. If missing, suggest `/init-wiki` then
   `/wiki-ingest`.
2. The user's question is provided (as argument or implicit prior turn).

## Algorithm

### Phase 1 — Index scan

Read `docs/llm_wiki/index.md`. Extract `(category, page-id, title, summary)`
tuples. Keep the entries whose title or summary contain at least one
term from the question. Also pick the top 3 entries per matched
category even without term overlap (general context).

### Phase 2 — Page read

For each candidate, Read the full wiki page. Skim for:
- Direct answer content.
- Cross-links (`[[page-id]]` or markdown links) to other wiki pages.
- `<!-- source: * -->` markers that reveal provenance.

If cross-links lead to pages not yet fetched and seem relevant, Read
them too (bounded: up to 10 additional pages total per query).

### Phase 3 — Compose answer

Write the answer as **plain text to the user** (not a file yet). Rules:
- Lead with a one-sentence conclusion.
- Cite each non-obvious claim with the wiki path: `(docs/llm_wiki/<path>.md)`.
- If the wiki has conflicting claims, surface the conflict rather than
  resolving silently.
- If the answer requires information not in the wiki, say so explicitly —
  suggest running `/wiki-ingest` or adding a Notion log entry.

### Phase 4 — (Optional) File back

If the user asks to save the answer, or the answer is a non-trivial
synthesis worth keeping:
1. Ask the user to confirm filing.
2. Create `docs/llm_wiki/explorations/<YYYY-MM-DD>-<slug>.md` with:
   ```yaml
   ---
   id: explorations.<date>-<slug>
   title: "<one-line question>"
   generated_by: wiki-query
   created: <iso8601>
   cites: [<list of wiki ids referenced>]
   ---
   ```
   followed by the answer body.
3. Append an entry to `docs/llm_wiki/log.md`.

## Forbidden

- Do NOT answer from general knowledge if the wiki is silent — say so.
- Do NOT modify canonical wiki pages from this skill.
- Do NOT call Notion MCP. Query is wiki-only.
- Do NOT make up citations. If you cite a file, it must exist and
  contain the claim.

## Arguments

- `<question>` — free-text question.
- `--file` — auto-file the answer without asking.
- `--no-file` — suppress the filing prompt.
- `--max-pages N` — cap on pages read (default 15).
