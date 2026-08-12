---
name: init
description: Scaffold the agent-os structure (under .agent-os/) plus a CLAUDE.md protocol section into the current project.
argument-hint: "[--no-eval]"
---

Scaffold **agent-os** into THIS project (the current working directory / repo root). All files go under `.agent-os/` so the project root stays clean; only `CLAUDE.md` is touched at the root.

Steps:
1. Parse `$ARGUMENTS`: the Validation eval set scaffolds by default; the flag `--no-eval` skips it.
2. Run the bundled scaffolder from the project root:
   ```
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/init.sh" [--no-eval]
   ```
3. If `bash` is unavailable, scaffold manually by copying the templates from `${CLAUDE_PLUGIN_ROOT}/templates/` into `.agent-os/` and the scripts from `${CLAUDE_PLUGIN_ROOT}/scripts/` into `.agent-os/scripts/`. NEVER overwrite existing files -- skip and report them. `CLAUDE.md` stays at the project root.
4. Report each created / skipped file.
5. Then state the follow-ups:
   - (Recommended) enable the forced-sync git hook: `git config core.hooksPath .agent-os/scripts/hooks`
   - Next: fill `.agent-os/docs/` with this project's **source of truth** from an initial full repo scan -- architecture, core logic, conventions, known risks. The scaffold only writes the `.agent-os/docs/README.md` index skeleton; the real content must come from the codebase.
   - The three skills (`task-scan`, `error-check`, `error-log`) are now available as `/agent-os:<skill>` and via auto-routing.

IMPORTANT: never fabricate project facts. All `.agent-os/docs/` content must come from scanning the actual repository.
