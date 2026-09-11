---
name: init
description: Scaffold the shared agent-os structure plus Claude/Codex root guidance into the current project.
argument-hint: "[--no-eval]"
---

Scaffold **agent-os** into THIS project (the current working directory / repo root).
Project memory stays under `.agent-os/`; host guidance is added at the root as both
`CLAUDE.md` (Claude Code) and `AGENTS.md` (Codex), from the same canonical protocol.

Steps:
1. Parse `$ARGUMENTS`: the Validation eval set scaffolds by default; `--no-eval` skips it.
2. Run from the project root:
   ```
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/init.sh" [--no-eval]
   ```
3. If `bash` is unavailable, reproduce `scripts/init.sh`: copy missing scaffold/templates and
   scripts, never overwrite project-owned memory, and add the canonical marked protocol block to
   both root guidance files while preserving existing text.
4. Report each created / skipped file.
5. State follow-ups:
   - enable the commit gate: `git config core.hooksPath .agent-os/scripts/hooks`
   - fill `.agent-os/docs/` from a real repository scan; never fabricate project facts
   - seed the Validation eval set from failures that actually happened
   - OpenAI hosts use the shared `agent-os-init` skill for the same workflow.

IMPORTANT: docs are verified source-of-truth material. Never invent project facts.
