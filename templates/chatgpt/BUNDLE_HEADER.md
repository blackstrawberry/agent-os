# agent-os — ChatGPT Project compatibility bundle

> Generated file. Do not edit this copy by hand.
> Version: @VERSION@
> Public source: @SOURCE@
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
