---
id: {{path_id}}
title: "{{title}}"
status: draft

source_notion_docs:
{{source_notion_list}}

refs:
{{refs_list}}

# Section-level provenance (Slice C)
section_sources:
{{section_sources_yaml}}    # e.g., "  \"Combat Mechanics\": notion:plan.combat-system"

code_references:
{{code_references_yaml}}    # output of: code-to-docs.py --frontmatter *.cs

owner: claude
last_refined: "{{last_refined}}"
refinement_hash: "{{refinement_hash}}"   # SHA256 over notion:* sections only
---

{{markdown_body}}
