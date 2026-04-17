---
description: Full pipeline — /notion-sync + /docs-refinement + git branch commit and push
argument-hint: (no arguments)
---

# /docs-update

Run the complete docs pipeline as one atomic operation:

1. **Pre-check** — `git status` must show clean `notion_docs/` and `develop_docs/`.
   If dirty, abort and ask user to commit or stash first.

2. **Create sync branch** — branch name format: `sync/notion-YYYYMMDD-HHMM`.
   ```bash
   ts=$(date -u '+%Y%m%d-%H%M')
   git checkout -b "sync/notion-$ts"
   ```

3. **Run `/notion-sync`** — invoke the notion-sync skill.

4. **Commit `notion_docs/` changes** (if any) —
   ```bash
   git add notion_docs/
   git diff --cached --quiet || git commit -m "sync(notion): mirror Notion pages to notion_docs/"
   ```

5. **Run `/docs-refinement`** — invoke the docs-refinement skill.

6. **Commit `develop_docs/` changes** (if any) —
   ```bash
   git add develop_docs/
   git diff --cached --quiet || git commit -m "refine(docs): regenerate affected develop_docs"
   ```

7. **Push to origin** —
   ```bash
   git push -u origin "sync/notion-$ts"
   ```
   On push failure: keep local branch, print recovery command, do NOT rollback.

8. **Report** — emit summary:
   ```
   sync branch: sync/notion-YYYYMMDD-HHMM
   commits: 2 (notion_docs, develop_docs)
   pushed: yes/no (with PR URL if available via gh)
   next: review and merge via PR; main is untouched.
   ```

## Forbidden

- Do NOT switch to `main` or merge the sync branch — human does that.
- Do NOT force-push.
- Do NOT skip the pre-check (must have clean working tree).
