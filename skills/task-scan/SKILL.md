---
name: task-scan
description: On a new request, scan .agent-os/prompts/tasks (and completed) frontmatter to find related prior tasks and route to the relevant source-of-truth docs. Use at the start of any task, when asked "did we do this before?", or when creating/archiving task docs.
---

# task-scan

<Purpose>
The front-desk router of agent-os. Connect a new request to existing context BEFORE touching code: find prior tasks and the source-of-truth docs that matter, so the work does not drift. All agent-os files live under `.agent-os/`.
</Purpose>

<Use_When>
- A new request arrives (step 1 of the work protocol).
- Creating a new task doc, or changing a task's status.
- The user asks whether similar work was done before, or to find related tasks.
</Use_When>

<Do_Not_Use_When>
- The change is a trivial one-off with no need for an audit trail.
</Do_Not_Use_When>

<Steps>
1. Query the INDEX, not every file: grep `.agent-os/prompts/index.jsonl` (one compact JSON line per task/error: `id/status/area/tags/summary/path/refs`). Match request keywords against the line. This keeps the scan O(1 file) and loads no bodies. If the index is missing or stale, run `sh .agent-os/scripts/reindex.sh` first; if there is no index at all, fall back to globbing `.agent-os/prompts/tasks/**/*.md` frontmatter.
2. Open a full `.md` body only for a strong match, then follow its `related_docs` / `related_errors`. If the index yields nothing and the topic may be old, also scan `.agent-os/prompts/archive/*.jsonl` (cold storage).
3. Read the relevant source of truth in `.agent-os/docs/` (use the `.agent-os/docs/README.md` index to pick by area).
4. New task -> create `.agent-os/prompts/tasks/NN_slug.md` (2-digit `NN`, kebab-case slug) using `.agent-os/prompts/tasks/_TEMPLATE.md`. Dates are real `YYYY-MM-DD`. Start at `status: planned`, move to `in-progress` when work begins.
5. On completion -> set `status: completed`, update `updated`, move the file to `.agent-os/prompts/tasks/completed/`, and fill `related_docs` / `related_errors`.
</Steps>

<Output>
A short note before starting: "Related tasks: [path -- summary]; docs to read: [path]" (or "no related tasks").
</Output>

<Self_Maintenance>
If the `.agent-os/prompts/` layout or the `_TEMPLATE.md` schema changes, update this skill's paths and field names in the same change. Every skill is subject to change.
</Self_Maintenance>
