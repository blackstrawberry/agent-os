# Evaluation set -- core-trap Q&A (v1)

> The rows below are filled-in EXAMPLES (a fictional app) showing the shape of a good eval row:
> a specific, decidable question, a one-line expected answer, and a source citation.
> **After the first repo scan, replace them with THIS project's real traps.**

| # | Question | Expected answer (gist) | Source |
|---|---|---|---|
| 1 | What is the one sanctioned way to query the DB? | All access goes through `core/db/repository.*`; never concat SQL -- use the parameterized query builder. | docs/05, docs/06 |
| 2 | What must never be edited directly, and why? | `legacy/billing/*` is frozen -- it mirrors the vendor calc engine; edits break reconciliation. Wrap it, don't change it. | docs/07 |
| 3 | First step on any new request? | task-scan (related prior tasks) -> read docs -> error-check, before touching code. | CLAUDE.md |
| 4 | Known recurring mistake in the auth area? | Token expiry was compared with `<` instead of `<=`, letting just-expired tokens through (see the logged error). | prompts/errors/ |
| 5 | Biggest security trap in this codebase? | User input reaches the legacy template renderer unescaped; sanitize before render. | docs/07 |

## Scoring
90%+ with sources cited = pass. Below that, strengthen the relevant doc/skill.
