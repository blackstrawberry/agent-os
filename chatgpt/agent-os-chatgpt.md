# agent-os — ChatGPT Project compatibility bundle

> Generated file. Do not edit this copy by hand.
> Version: 0.9.0
> Public source: https://github.com/blackstrawberry/agent-os
> Compatibility profile: `templates/chatgpt/profile.txt`

This bundle adapts canonical agent-os Skills to ChatGPT **Project compatibility mode**. It does not
turn a Project into a local shell runtime or a Native Skill installation.

## Capability contract

- Use only tools/actions that the current surface actually exposes and the current user is authorized to use.
- A connected GitHub/app/plugin name alone does not imply repository write access.
- Never claim a task/file/status/commit/push changed unless a successful write action actually happened.
- Shell snippets and hook/script instructions below are conditional: execute them only when shell capability exists.
- Keep retrieval bounded. For broad work read known risks, then the strongest related task/ADR/error records.
- If repository search returns an ambiguous zero, use the E0011 fallback: list known `.agent-os` directories, shortlist by filename/frontmatter/path, then open at most three strongest records.

## Included canonical Skills

---

## Skill: `agent-os`

Canonical source: `skills/agent-os/SKILL.md`

<canonical-skill>
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
4. Without shell, try repository search over task/error/ADR frontmatter. **A zero result is not
   proof of no history when code search may be unavailable or unindexed.** In that case list the
   known `.agent-os/prompts/tasks`, `tasks/completed`, `prompts/errors`, and `docs/adr` directories,
   shortlist by filename/frontmatter/path, then open at most the three strongest records.
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
Budget 2200 chars.
</Self_Maintenance>

</canonical-skill>

---

## Skill: `task-scan`

Canonical source: `skills/task-scan/SKILL.md`

<canonical-skill>
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

</canonical-skill>

---

## Skill: `error-check`

Canonical source: `skills/error-check/SKILL.md`

<canonical-skill>
---
name: error-check
description: Before local or broad code work, check agent-os known risks and prior error records so the same trap is not repeated. Use before editing/debugging, on recurring-error questions, and in ChatGPT-style repository analysis as well as shell-capable hosts.
---

# error-check

<Purpose>
Read durable lessons and the most relevant error history BEFORE changing code.
</Purpose>

<Steps>
0. Read `.agent-os/docs/07_known-risks.md` first. What it already covers needs no incident dump.

1. Find prior errors without loading them all.
   **Shell available:**
   ```sh
   sh .agent-os/scripts/rank.sh -q "<what you are about to do>" -f "<paths>" -k error -n 8
   ```
   **No shell:** search `.agent-os/prompts/errors/` by root cause, summary, tags, keywords and
   touched paths. If code search is unavailable, unindexed, or an empty result is ambiguous,
   list the errors directory and shortlist by filename/frontmatter/path instead. Include archived
   error JSONL only for old topics. Prefer path/root-cause hits. Open the top 3 at most.

2. Read root cause and prevention on matches and apply them now. A recorded file-path hit matters
   even when wording differs. Follow `related_errors` when a hit says it recurred from another id.

3. If retrieval should have matched but did not, first distinguish **unindexed search** from a
   missing vocabulary alias. Writable hosts add a truly missing alias to `.agent-os/vocab.txt`;
   read-only hosts report it instead.
</Steps>

<Output>
"Related past errors: [id -- summary -- caution]" — or "no related history". Then proceed.
Never claim a repository update in read-only mode.
</Output>

<Links>
A new mistake -> `error-log`.
</Links>

<Self_Maintenance>
Sync matched fields with `prompts/errors/_TEMPLATE.md`. Keep retrieval bounded.
</Self_Maintenance>

</canonical-skill>

---

## Skill: `error-log`

Canonical source: `skills/error-log/SKILL.md`

<canonical-skill>
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

</canonical-skill>
