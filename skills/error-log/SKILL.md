---
name: error-log
description: When the agent judges it made a mistake or error during work, self-write a structured doc (with frontmatter) into .agent-os/prompts/errors. Use on wrong assumptions, broken fixes, wrong tool/path usage, regressions, and security slips. Also use on "log this error" / "record the mistake" requests.
---

# error-log

<Purpose>
Mistakes as a structured pattern, not a raw log. Record your own unasked.
</Purpose>

<Use_When>
A wrong assumption, a fix that broke something, a wrong file/tool/path, a security or data
near-miss, or the user pointing out a mistake.
Not for a self-corrected typo that cannot recur.
</Use_When>

<Steps>
1. **Check for a recurrence first — do not reach for an id yet.**
   ```sh
   sh .agent-os/scripts/rank.sh -q "<root cause in your own words>" -f "<files>" -k error -n 5
   ```
   Compare **root causes**, not symptoms — one cause wears many symptoms. Judge on `rc`.

2. **Same root cause -> no new doc** (a second file splits one trap into apparent one-offs).
   Update it: bump `recurrence`, `last_seen` = today, `status: open` again if it had been
   resolved, add new paths to `files`, add a `## Recurrence history` row. Add, never overwrite.

3. **Different root cause -> new doc.** Match the id convention already in the directory
   (`E0007_slug.md` or `ERR-YYYY-MM-DD-slug.md` — do not assume). Cross-link the near-miss
   you compared against via `related_errors` on both sides.
   - Fill every field the template lists; its comments carry the allowed values.
     **Enums: exactly one word, nothing appended** — the linter rejects the rest.
     `tags` 3-8 words the next person will type hitting this same wall.
     Never write secret values — point at the location.

4. Body: what happened (quote messages verbatim) / root cause (verified) / fix / prevention /
   recurrence history. Add the id to the related task's `related_errors`.

5. **At `recurrence` 3+, editing the doc is not a response.** Promote it to
   `docs/07_known-risks.md`, or open a task for a mechanical gate (hook, lint, test).
</Steps>

<Output>
New: path + one-line lesson. Recurrence: which doc, to what count, and at 3+ which escalation.
</Output>

<Self_Maintenance>
Sync with `prompts/errors/_TEMPLATE.md`. Budget 2000 chars.
</Self_Maintenance>
