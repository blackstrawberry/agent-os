---
name: agent-os-init
description: Initialize or update agent-os in the current repository. Use when asked to install, scaffold, bootstrap, migrate, or refresh agent-os. In a shell-capable host run the bundled installer; with repository write tools reproduce the same safe rules; in read-only mode report the exact changes without pretending they were applied.
---

# agent-os-init

<Purpose>
Create or refresh the shared `.agent-os/` memory structure plus host guidance without overwriting
project-owned memory.
</Purpose>

<Full_Mode>
From the repository root run:
```sh
bash "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}/scripts/init.sh" [--no-eval]
```
For an existing installation use `--update`. The installer owns scripts and the marked protocol
blocks; the project owns docs, prompt history, vocab and customized templates.
</Full_Mode>

<Repository_Write_Mode>
If shell is unavailable but repository write tools exist, follow `scripts/init.sh` exactly:
- create missing `.agent-os/` scaffold files from `templates/` and scripts from `scripts/`;
- never overwrite project-owned docs/history/vocab;
- add or refresh only the `<!-- agent-os:begin -->` ... `<!-- agent-os:end -->` block in root
  `CLAUDE.md` and root `AGENTS.md`, preserving all text outside the markers;
- do not fabricate source-of-truth docs. They must come from scanning real code.
</Repository_Write_Mode>

<Read_Only_Mode>
Inspect whether `.agent-os/`, `CLAUDE.md` and `AGENTS.md` exist. Return a concrete migration plan
and the files that would be created/updated. Do not say initialization completed.
</Read_Only_Mode>

<After>
Recommend enabling the commit gate in local/full mode:
`git config core.hooksPath .agent-os/scripts/hooks`
Then populate `.agent-os/docs/` from a real repository scan and seed the eval set with failures
that actually occurred.
</After>
