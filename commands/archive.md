---
name: archive
description: Archive COLD agent-os task/error docs so the active index stays small. This is repository-memory maintenance, not chat/context compaction. Preview first, apply only on confirmation.
argument-hint: "[--apply]"
---

Archive cold **agent-os docs** in THIS project. OpenAI hosts use the shared
`agent-os-archive` skill for the same workflow.

> This is NOT conversation/context compaction. Native chat compaction is separate.

A document is cold only if it is finished/resolved, has no inbound references, is not pinned,
and is outside the age window. Age alone is never enough.

0. If `.agent-os/` is absent, stop and run initialization first.
1. Refresh: `sh .agent-os/scripts/reindex.sh`.
2. Preview: `sh .agent-os/scripts/agent-os-compact.sh`. Show the list.
3. Before recurring errors leave active memory, promote durable lessons to
   `.agent-os/docs/07_known-risks.md`.
4. Apply only on confirmation: `sh .agent-os/scripts/agent-os-compact.sh --apply`.
5. Report archived paths. Full text remains in git history.

Tunables: `AGENT_OS_ARCHIVE_AGE_DAYS` and `AGENT_OS_MAX_ACTIVE`.
