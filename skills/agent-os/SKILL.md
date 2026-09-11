---
name: agent-os
description: Use agent-os project memory and operating protocol when a repository contains .agent-os/, when the user asks to follow agent-os, or when working on task/error/ADR/source-of-truth history. Route by work size, read known risks first, retrieve only the most relevant prior records, and adapt to the host's available read/write/shell capabilities.
---

# agent-os

<Purpose>
Use the repository's `.agent-os/` memory without assuming a particular host. The memory model
is shared; only the way files and scripts are accessed changes between Claude Code, Codex,
ChatGPT, and other capable hosts.
</Purpose>

<Mode>
Choose capability-first, not product-name-first:

- **Full mode**: repository files are writable and shell commands can run. Use the scripts and
  normal task/error lifecycle directly.
- **Repository mode**: repository search/read/write tools exist but no shell. Read the same
  source files with repository tools; edit docs only if write actions are actually available.
- **Read-only mode**: search/read only. Research and return the relevant history, risks and
  proposed task/update. Never claim a file, status, commit or push was changed.
</Mode>

<Protocol>
1. Size the request: trivial -> act; local -> `error-check`; broad -> task history + known risks
   + error history before implementation.
2. For broad work read `.agent-os/docs/07_known-risks.md` first, then find related tasks/ADRs.
3. Full mode retrieval:
   ```sh
   sh .agent-os/scripts/rank.sh -q "<request words>" -f "<paths>" -n 8
   ```
   Open the top 3 at most. Add `-k task` or `-k error` when the kind matters.
4. Without shell, search task/error/ADR frontmatter by request words, file paths, tags and
   summaries. Prefer file-path matches. Open at most the three strongest records.
5. Code is ground truth; docs are source of truth. If they disagree, fix the docs in the same
   writable change. Never copy secrets into memory documents.
6. Finish writable broad work by updating docs, setting the task `status: completed`, and moving
   it to `prompts/tasks/completed/`. Read-only hosts instead report the exact closeout changes
   that remain.
</Protocol>

<Links>
Bootstrap -> `agent-os-init`. Cold-doc maintenance -> `agent-os-archive`.
Task history -> `task-scan`. Prior mistakes -> `error-check`. New mistake -> `error-log`.
</Links>

<Self_Maintenance>
Keep this skill host-neutral. Platform-specific installation belongs in README/GUIDE, not here.
Budget 2000 chars.
</Self_Maintenance>
