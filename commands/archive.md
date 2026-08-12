---
name: archive
description: Archive COLD agent-os task/error DOCS (finished, unreferenced, unpinned, old) into .agent-os/prompts/archive/*.jsonl so the active index stays small and cheap to scan. This is agent-os memory maintenance and is NOT conversation/context compaction -- the built-in /compact handles that. Previews first, then applies on confirmation.
argument-hint: "[--apply]"
---

Archive cold **agent-os docs** in THIS project.

> This is NOT conversation/context compaction. The built-in `/compact` compacts the chat context; this command only moves finished, unreferenced agent-os task/error docs out of the active index. Never run this in place of the native `/compact`.

Coldness is not age alone: a doc is archived only if it is finished (completed/resolved) AND has no inbound references (`refs == 0`) AND is not pinned (`pin: true`) AND was not updated within the age window. Pinned, referenced, recent, open, or active docs are never archived.

0. **Guard.** If there is no `.agent-os/` directory in this project, STOP and tell the user this project is not agent-os-scaffolded (run `/agent-os:init` first). Do NOT run the steps below -- the scripts do not exist here.

Steps:
1. Refresh the index: `sh .agent-os/scripts/reindex.sh`.
2. Preview cold docs (dry-run): `sh .agent-os/scripts/agent-os-compact.sh`. Show the list to the user.
3. Before archiving recurring errors, roll their lesson up into `.agent-os/docs/` (known-risks) so the knowledge is preserved, not just stored. (This is the highest-value compression: N similar errors -> 1 documented rule.)
4. On confirmation, apply: `sh .agent-os/scripts/agent-os-compact.sh --apply`. This appends a summary line to `.agent-os/prompts/archive/<kind>s-<year>.jsonl`, removes the `.md`, and reindexes. The full text stays in git history.
5. Report what was archived. Restore any doc with `git log -- <path>` / `git show`.

Tunables: `AGENT_OS_ARCHIVE_AGE_DAYS` (default 90), `AGENT_OS_MAX_ACTIVE` (default `AGENT_OS_CONTEXT_TOKENS`/1000).
