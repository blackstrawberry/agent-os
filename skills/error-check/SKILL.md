---
name: error-check
description: Before or while working, scan .agent-os/prompts/errors frontmatter to check whether the same or a similar mistake happened before, and avoid repeating it. Use before editing code, before debugging, on "have I made this mistake before?", or when a recurring error is suspected.
---

# error-check

<Purpose>
Look at the error history FIRST so you do not fall into the same trap twice. Structured past mistakes are the bridge between a request and the right caution.
</Purpose>

<Use_When>
- Just before execution (step 3 of the work protocol).
- Especially before high-risk work: shared core, DB queries, environment-specific code, external integrations.
</Use_When>

<Steps>
1. Query the INDEX first: grep `.agent-os/prompts/index.jsonl` for `"k":"error"` lines and match `area` / `cat` / `summary` against the current target. Open a full error `.md` only for a strong match. If the index is missing, run `sh .agent-os/scripts/reindex.sh`, or fall back to scanning `.agent-os/prompts/errors/*.md` frontmatter. For old/rare topics, also check `.agent-os/prompts/archive/errors-*.jsonl`.
   - By area: same `area`. By file: the file you will touch appears in some error's `files`. By type: the `category` this work tends to trigger.
2. Read the "root cause" and "prevention" sections of any match and apply them now.
3. If matches exist, warn briefly: "Past EXXXX in the same area -- watch out for: ...".
</Steps>

<Output>
A short note: "Related past errors: [EXXXX -- summary -- caution]" (or "no related history"), then proceed.
</Output>

<Links>
- New mistake during work -> use the `error-log` skill to record it.
- Recurring pattern -> promote it to `.agent-os/docs/` (known-risks) or `CLAUDE.md` so it is enforced, not just remembered.
</Links>

<Self_Maintenance>
If the `.agent-os/prompts/errors/_TEMPLATE.md` schema changes, update this skill's matched fields in the same change.
</Self_Maintenance>
