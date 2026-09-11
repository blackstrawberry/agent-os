---
name: agent-os-archive
description: Maintain agent-os bounded memory by previewing and, after approval, archiving cold completed/resolved unreferenced unpinned task and error docs. Use for agent-os archive, compaction, cold-memory cleanup, or active-index size maintenance. Never confuse this with chat/context compaction.
---

# agent-os-archive

<Purpose>
Keep the active agent-os index small without discarding lessons. This archives repository docs,
not conversation context.
</Purpose>

<Guard>
If `.agent-os/` is absent, stop: this repository is not initialized. Never create an archive
structure as a side effect of an archive request.
</Guard>

<Full_Mode>
1. Refresh: `sh .agent-os/scripts/reindex.sh`.
2. Preview only: `sh .agent-os/scripts/agent-os-compact.sh`.
3. Before recurring errors leave active memory, promote their durable lesson to
   `.agent-os/docs/07_known-risks.md`.
4. Apply only after user approval: `sh .agent-os/scripts/agent-os-compact.sh --apply`.
5. Report archived paths. Full text remains recoverable from git history.
</Full_Mode>

<Repository_Mode>
Without shell, reproduce the coldness rule from the script only when the repository tools expose
all required metadata: finished/resolved, zero inbound references, not pinned, outside the age
window. Preview first. Apply repository writes only after approval and only if append/delete
operations are available.
</Repository_Mode>

<Read_Only_Mode>
Identify likely candidates and explain why. Do not claim anything was archived.
</Read_Only_Mode>

<Rule>
Age alone never makes a document cold. Promoting the durable lesson before archiving the incident
is what makes compaction safe.
</Rule>
