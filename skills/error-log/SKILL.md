---
name: error-log
description: Record an agent mistake as structured agent-os error memory, or update the existing record when the root cause recurs. Use on wrong assumptions, broken fixes, wrong tool/path usage, regressions, security slips, or explicit requests to log a mistake. In read-only hosts, prepare the exact update without claiming it was written.
---

# error-log

<Purpose>
Turn repeatable mistakes into structured patterns, not raw logs.
</Purpose>

<Steps>
1. Check recurrence before choosing an id.
   **Shell available:**
   ```sh
   sh .agent-os/scripts/rank.sh -q "<root cause>" -f "<files>" -k error -n 5
   ```
   **No shell:** search `.agent-os/prompts/errors/` by root cause, paths, tags and summary. If code
   search is unavailable, unindexed, or an empty result is ambiguous, list the errors directory
   and inspect likely filename/frontmatter/path matches before declaring the root cause new.
   Compare root causes, not symptoms; open only the strongest few candidates.

2. Same root cause -> no new doc. In a writable host bump `recurrence`, set `last_seen` to today,
   reopen if needed, merge new paths, and append a recurrence-history row. In read-only mode,
   return that exact proposed edit.

3. Different root cause -> writable hosts create the next id using the directory's existing id
   convention and `_TEMPLATE.md`. Fill every required field; enums are exact values, tags are
   words someone will search later, and secrets are never copied. Read-only hosts return the
   proposed path/frontmatter/body and state it was not written.

4. Record: what happened, verified root cause, fix, prevention, recurrence history. Cross-link the
   related task and near-miss errors when applicable.

5. At `recurrence` 3+, editing the incident is not enough: promote the lesson to
   `docs/07_known-risks.md` or open a task for a mechanical gate.
</Steps>

<Output>
New: path + one-line lesson. Recurrence: document + new count + required escalation at 3+.
</Output>

<Self_Maintenance>
Sync with `prompts/errors/_TEMPLATE.md`. Keep this workflow host-neutral.
</Self_Maintenance>
