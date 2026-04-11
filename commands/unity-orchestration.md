---
name: unity-orchestration
description: Run a Unity task through a 9-agent consensus team.
argument-hint: "<task description>"
---

Invoke the `unity-orchestration` skill from the `unity-orchestration` plugin
with the user's task description as input.

User task: $ARGUMENTS

Use the Skill tool to load `unity-orchestration` and follow its bootstrap
procedure. Do not spawn agents directly from this command — the skill owns
that flow.
