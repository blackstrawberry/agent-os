---
name: task-scan
description: On a new request, scan .agent-os/prompts/tasks (and completed) frontmatter to find related prior tasks and route to the relevant source-of-truth docs. Use at the start of any task, when asked "did we do this before?", or when creating/archiving task docs.
---

# task-scan

<Purpose>
Connect a request to existing context BEFORE touching code.
</Purpose>

<Use_When>
Broad work (many files, design change, new feature); creating a task doc or changing its
status; "did we do this before?".
Not for trivial or local work — a one-file bug fix needs `error-check`, not this.
</Use_When>

<Steps>
1. Rank, do not scan:
   ```sh
   sh .agent-os/scripts/rank.sh -q "<words from the request>" -f "<paths you will touch>" -n 8
   ```
   `SCORE<TAB><index line>`, best first. **Open the top 3 at most.**
   - Score 10+ = a **file hit**: a path you will touch is in that doc's `files`. Read it even
     with no keyword match. Pass real paths to `-f`; that is what beats grep.
   - No `rank.sh` or non-zero exit: grep the index. No index: `reindex.sh`.

2. A decision record (`"k":"adr"`) in the results: **read it before proposing anything.**
   Check its *Revisit when* — condition met, say so and proceed; not met, it stands.

3. Read `.agent-os/docs/` — `07_known-risks.md` first. Follow a match's `related_docs` /
   `related_errors`. Old topic: also `prompts/archive/*.jsonl`.

4. New task -> `prompts/tasks/NN_slug.md` from `_TEMPLATE.md`. Real dates, `status: planned`.
   **`tags` is not optional** — 3-8 words *you would search for months from now*, not words
   already in the title. Include one canonical term from `.agent-os/vocab.txt` when one fits.

5. Done -> `status: completed`, update `updated`, move to `tasks/completed/`, fill
   `related_docs` / `related_errors`.
</Steps>

<Output>
"Related: [path -- summary]; docs to read: [path]" — or "no related tasks".
</Output>

<Self_Maintenance>
Sync paths and field names with `.agent-os/prompts/` and the templates. Budget 2000 chars.
</Self_Maintenance>
