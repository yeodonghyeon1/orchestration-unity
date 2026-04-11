# Dry-run scenarios (manual checklist, v1)

Automated scenario tests are out of scope for v1. These manual scenarios
are the minimum regression pass before each release.

Run every scenario from a clean tmp dir. Copy the plugin into the tmp dir
so the scripts' `PLUGIN_ROOT` resolution works.

## Scenario 1 — init-workspace on empty project

1. `mkdir /tmp/scn-init && cd /tmp/scn-init`
2. Run `bash <plugin>/skills/unity-orchestration/scripts/init-workspace.sh . demo`
3. Verify:
   - `.orchestration/sessions/<timestamp>-demo/state.json` exists and is
     valid JSON with `phase=boot`.
   - `docs/` mirrors the seed template.

## Scenario 2 — tally-votes pass & fail

Use `tests/fixtures/votes/round-pass/` and `round-fail/`:

```
bash skills/unity-orchestration/scripts/tally-votes.sh \
  --round 1 --type plan --task demo \
  --input tests/fixtures/votes/round-pass \
  --output /tmp/pass.md
echo $?   # 0
bash skills/unity-orchestration/scripts/tally-votes.sh \
  --round 1 --type plan --task demo \
  --input tests/fixtures/votes/round-fail \
  --output /tmp/fail.md
echo $?   # 1
```

Inspect the output files for the required sections.

## Scenario 3 — update-docs-index on the seed template

```
python3 skills/unity-orchestration/scripts/update-docs-index.py \
  skills/unity-orchestration/templates/docs-tree
cat skills/unity-orchestration/templates/docs-tree/_meta/index.json | head -30
```
A single `warn:` about `CHANGELOG.md: no frontmatter` is expected and
acceptable. `tree` should contain entries for root, game, design, tech.

## Scenario 4 — structure-check full pass

```
bash tests/structure-check.sh
echo $?   # 0
```

## Scenario 5 — structure-check on a tampered plugin

1. Copy plugin to `/tmp/scn5`.
2. Delete `skills/unity-orchestration/agents/designer.md`.
3. `bash tests/structure-check.sh`
4. Expect: FAIL with message about designer.md missing/no frontmatter.
   Exit 1.

## Regression signoff

Maintainer runs all five scenarios before tagging a release. Record the
result in the release PR description.
