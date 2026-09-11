---
name: task-scan
description: On a new broad request, find related agent-os tasks and decisions before code changes. Use when asked whether work was done before, when creating/closing task docs, or for multi-file/design work. Works with shell ranking when available and repository search/read tools in ChatGPT-style hosts.
---

# task-scan

<Purpose>
Connect a request to existing context BEFORE touching code.
</Purpose>

<Use_When>
Broad work; creating/closing task docs; "did we do this before?". Not for trivial work. A
one-file bug normally needs `error-check` only.
</Use_When>

<Steps>
1. Retrieve, do not dump the corpus.
   **Shell available:**
   ```sh
   sh .agent-os/scripts/rank.sh -q "<request words>" -f "<paths>" -n 8
   ```
   **No shell:** search `.agent-os/prompts/tasks/`, `tasks/completed/` and
   `.agent-os/docs/adr/` by request words, tags, summary and paths. If code search is unavailable,
   unindexed, or a zero result cannot be distinguished from an index miss, list those known
   directories instead and shortlist by filename/frontmatter/path. Open the top 3 at most.

2. A decision record hit must be read before proposing the rejected option again. Check
   *Revisit when*: unmet means the decision still stands.

3. Read `.agent-os/docs/07_known-risks.md` and follow relevant `related_docs` /
   `related_errors`. For old topics include `prompts/archive/*.jsonl` if accessible.

4. New writable task -> `prompts/tasks/NN_slug.md` from `_TEMPLATE.md`, real dates,
   `status: planned`, 3-8 useful `tags`, and relevant `files`.
   In a read-only host, return the proposed path/frontmatter and say it was not written.

5. Done in a writable host -> `status: completed`, update `updated`, move to
   `tasks/completed/`, and fill related docs/errors. Read-only hosts report those closeout
   changes instead of claiming them.
</Steps>

<Output>
"Related: [path -- summary]; docs to read: [path]" — or "no related tasks".
</Output>

<Self_Maintenance>
Sync paths/fields with `.agent-os/prompts/` and its templates. Keep retrieval bounded.
</Self_Maintenance>
