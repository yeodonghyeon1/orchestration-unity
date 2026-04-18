---
description: Drive a Unity game development task through the full Superpowers discipline chain
argument-hint: "<task description, e.g., 'add enemy patrol system'>"
---

# /unity-orchestration

Run the provided `<task>` through the eleven-step Superpowers chain,
backed by `develop_docs/` context and `unity-mcp` execution.

If no argument provided: prompt user for task description; do not proceed without it.

Invoke the skill:

```
Skill('unity-orchestration')
```

The skill enforces:
- HARD-GATE on brainstorming before planning
- User approval gate on the written plan before code is written
- TDD Iron Law (failing test first)
- Verification before completion

Interrupts allowed at: after Step 1 (brainstorm outcome unsatisfactory),
after Step 4 (plan unsatisfactory), after Step 9 (verification surfaces issues).

See `skills/unity-orchestration/workflow.md` for the full step-by-step flow.
