<!-- agent-os:begin -->
## Agent Operating Protocol (agent-os)

> Every task follows this order. Read the relevant docs BEFORE working; sync docs/skills AFTER.
> Model: Foundation (this guide) -> Source of Truth (.agent-os/docs/) -> Skills -> Validation.
> All agent-os files live under `.agent-os/` to keep the project root clean.

### Fast path (read first)
**Trivial ops run DIRECTLY -- no protocol, no scans.** A commit, a push, a single shell command, a one-line answer, a small clarification: just do it. NEVER run task-scan / read-docs / error-check because the user said "commit", "push", or "run X". Treating a commit as substantive work is the #1 cause of a simple request taking minutes -- do not do it. When unsure whether a request is trivial, assume trivial and skip the protocol.

### Work protocol
> Scope: the numbered steps below apply ONLY to **substantive work** -- multi-step changes, new features, debugging, refactors. Anything on the Fast path above skips all of it.
1. **task-scan** -- on a new request, scan `.agent-os/prompts/tasks/` (+`completed/`) frontmatter for related prior tasks and context. (skill `/agent-os:task-scan`)
2. **Read docs** -- read `.agent-os/docs/` for the area to orient yourself. Treat docs as a verified summary that can drift -- **the code is ground truth.** If code and docs disagree, trust the code, **fix the doc** in the same change, and log it (error-log).
3. **error-check** -- scan `.agent-os/prompts/errors/` frontmatter for past mistakes in this area. (skill `/agent-os:error-check`)
4. **Execute**.
5. **error-log** -- if you judge you made a mistake/error, record it yourself in `.agent-os/prompts/errors/`. (skill `/agent-os:error-log`)
6. **Sync** -- when behavior or design changes, update `.agent-os/docs/` and skills **in the same change**.
7. **Close** -- on completion set frontmatter `status: completed` and move the task to `.agent-os/prompts/tasks/completed/`.

### Source of Truth (.agent-os/docs/)
- `.agent-os/docs/` is the single source of truth for structure and core logic. Index: `.agent-os/docs/README.md`.
- Change shared core / schema / flow / conventions -> fix the matching docs in the same change. Do not mark a task complete if docs are stale.
- NEVER copy secret values (credentials, keys) into docs/prompts/chat. Point at the file location only.
- Write only VERIFIED facts. Do not infer where a symbol is defined from a `require`/import line -- confirm with grep before documenting.

### Forced sync (opt-in)
- `.agent-os/scripts/hooks/pre-commit` -- (1) blocks commits with missing prompt frontmatter, (2) warns when code changes without a `.agent-os/docs/` update.
- Enable once: `git config core.hooksPath .agent-os/scripts/hooks`. Manual check: `sh .agent-os/scripts/check-prompts.sh`.

### Scaling (keep memory cheap to scan)
- Scan `.agent-os/prompts/index.jsonl` (generated catalog), not every file. Regenerate: `sh .agent-os/scripts/reindex.sh` (pre-commit keeps it fresh).
- Compact COLD docs only: finished AND unreferenced (`refs == 0`) AND unpinned AND not recently updated. Old-but-referenced or old-but-edited docs stay. Preview `sh .agent-os/scripts/agent-os-compact.sh`; apply via `/agent-os:archive`. Pin permanent docs with `pin: true`.
- Roll recurring error lessons into `.agent-os/docs/` (known-risks) before archiving.

### Skill management
- Skills: `task-scan`, `error-check`, `error-log` (agent-os plugin). Turn recurring work into a skill.
- If a path/schema a skill or doc references drifts as the project changes, fix it in the same change. Every skill is subject to change.
<!-- agent-os:end -->
