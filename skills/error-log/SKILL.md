---
name: error-log
description: When the agent judges it made a mistake or error during work, self-write a structured doc (with frontmatter) into .agent-os/prompts/errors. Use on wrong assumptions, broken fixes, wrong tool/path usage, regressions, and security slips. Also use on "log this error" / "record the mistake" requests.
---

# error-log

<Purpose>
Leave mistakes as a STRUCTURED pattern, not a raw log, so the next task is more accurate. The agent records its own errors without being asked.
</Purpose>

<Use_When>
- You discover you worked from a wrong assumption.
- A fix broke something (regression).
- You used the wrong file / tool / path.
- You did, or nearly did, something risky for security or data.
- The user points out a mistake.
</Use_When>

<Do_Not_Use_When>
- A trivial self-corrected typo with no chance of recurrence or impact. Log only mistakes that can recur or that mattered.
</Do_Not_Use_When>

<Steps>
1. Next id = max existing `EXXXX` in `.agent-os/prompts/errors/` + 1 (4 digits, e.g. `E0001`).
2. Create `.agent-os/prompts/errors/EXXXX_slug.md` using `.agent-os/prompts/errors/_TEMPLATE.md`. Fill `date` (real `YYYY-MM-DD`), `task`, `severity`, `category` (assumption|tooling|logic|env|regression|security|data), `area`, `files`, `summary`, `status` (open|resolved).
   - SECURITY: never write secret values verbatim. Point at the location ("the credential in config"), do not copy it.
3. Body = 4 sections: what happened (quote error messages verbatim) / root cause (verified, not guessed) / how it was fixed / prevention (the lesson).
4. Add this id to the related task's `related_errors` frontmatter.
5. If the prevention is a general rule, promote it to `.agent-os/docs/` (known-risks) / `CLAUDE.md` / the relevant skill.
</Steps>

<Output>
Report the created path plus a one-line lesson.
</Output>

<Self_Maintenance>
If the frontmatter schema changes, keep this skill and `.agent-os/prompts/errors/_TEMPLATE.md` in sync.
</Self_Maintenance>
