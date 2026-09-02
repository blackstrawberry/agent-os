# .agent-os/prompts/ — task & error documents

Keeps the agent from losing context by storing **requests (task)** and **mistakes (error)** in a structured form. Every doc carries **frontmatter** so it can be scanned fast (request <-> relevant doc). Everything lives under `.agent-os/` so the project root stays clean.

## Layout
```
.agent-os/prompts/
├── README.md            <- this file
├── tasks/
│   ├── _TEMPLATE.md     <- task frontmatter schema
│   ├── NN_slug.md       <- active task (planned/in-progress/blocked)
│   └── completed/       <- completed-task archive
├── errors/
│   ├── _TEMPLATE.md     <- error frontmatter schema
│   └── EXXXX_slug.md    <- error / mistake history
├── eval/                <- (optional) offline evaluation set (Validation layer)
├── reference/           <- (optional) methodology / study references (not tasks)
├── index.jsonl          <- generated catalog (1 line per task/error) for cheap scans
└── archive/             <- cold docs compacted to *.jsonl (full text stays in git)
```

## Rules
- **Tasks**: `tasks/NN_slug.md` (2-digit number, kebab-case slug). Status flow: `planned -> in-progress -> completed` (or `blocked`). On completion, move to `tasks/completed/`.
- **Errors**: when the agent judges it made a mistake, it writes `errors/EXXXX_slug.md` itself (skill `error-log`).
- **Scan first**: before working, use `task-scan` (related tasks) and `error-check` (past mistakes) to read frontmatter and gather context.
- Frontmatter fields must match `_TEMPLATE.md`. If the schema changes, update the related skills in the same change.
- **Not indexed / not linted**: `_TEMPLATE.md` and any `tasks/manual-*.md` are skipped by the indexer (`reindex.sh`) and the frontmatter linter (`check-prompts.sh`). Use a `manual-*.md` name for hand-written notes that are not tracked tasks.

## Scaling (don't let memory grow unbounded)
- **Scan the index, not every file.** `.agent-os/prompts/index.jsonl` is a generated catalog (one compact line per task/error). Skills query it; regenerate with `sh .agent-os/scripts/reindex.sh` (the pre-commit hook keeps it fresh).
- **Compaction is by coldness, not age.** A finished doc is archived only if it is also unreferenced (`refs == 0`), unpinned, AND not recently updated. Frequently referenced or recently edited docs stay hot no matter how old. Preview with `sh .agent-os/scripts/agent-os-compact.sh`; archive with `--apply` (or `/agent-os:archive`).
- **Pin** load-bearing docs with `pin: true` in frontmatter so they are never archived. `pin` is not an importance marker -- a doc another doc references already has `refs > 0` and is safe without it. Over-pinning makes cold detection impossible, and it is the measured failure: one install had pinned 20 of its 21 docs and had no `archive/` at all. `agent-os-health.sh` warns past 30% and names pinned docs nothing has touched in 180 days.
- Archived docs become a summary line in `.agent-os/prompts/archive/*.jsonl`; full text remains in git history (`git show`). Roll recurring error lessons into `.agent-os/docs/` before archiving.
