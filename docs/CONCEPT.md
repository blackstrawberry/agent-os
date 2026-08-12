# The idea behind agent-os

**Languages:** English | [한국어](CONCEPT.ko.md) | [日本語](CONCEPT.ja.md)

> Read this if you want to understand *why* the plugin is shaped the way it is -- and decide whether to adopt it.

## The problem

On a large, old, or messy codebase, an AI agent's intent leaks. It assumes instead of verifying, re-derives the same context every session, repeats mistakes it already made, and lets documentation drift until the docs actively mislead. The bottleneck is not the model's intelligence -- it is the **absence of structure that connects a request to the right knowledge**.

A pile of raw history (old commits, old tickets, thousands of past queries) does not fix this. The idea agent-os borrows -- from Anthropic's writing on building *skills* for AI agents -- is that feeding a model more raw history barely moves accuracy; what moves it is **structured procedural knowledge**: not "here is the data," but "here is how an expert works through this." That procedural knowledge is what they call a *skill*. agent-os is a small, general -- and so far unmeasured -- application of that idea to everyday coding work; the Validation layer is how you measure whether it actually helps on *your* project.

## The model: four layers

```
Foundation      CLAUDE.md     the operating protocol the agent always follows
Source of Truth .agent-os/docs/         the single, verified description of the system
Skills          .claude/...   reusable "how to work" procedures (routers + cookbooks)
Validation      .agent-os/prompts/eval  known-answer checks that prove the system still works
```

- **Foundation** -- one always-loaded guide (`CLAUDE.md`) that says, for *every* request: scan prior tasks, read the source of truth, check past errors, execute, log new errors, sync docs. It is the top-level router.
- **Source of Truth** -- `.agent-os/docs/` holds the project's architecture, core logic, conventions, and known risks. It is written from a real scan of the code, not from assumption, and it is what the agent consults first to orient itself. The code is still ground truth: when code and docs disagree, you trust the code and **fix the docs**.
- **Skills** -- small procedures the agent invokes. Two kinds, mirroring Anthropic's split: *router* skills that point to the ~right slice of context (a "front desk"), and *cookbook* skills that run a vetted workflow. agent-os ships three routers: `task-scan`, `error-check`, `error-log`.
- **Validation** -- an offline eval set (`.agent-os/prompts/eval/`) of questions with known answers, drawn from the project's real traps. It lets you prove that a .agent-os/docs/skill change improved things instead of guessing.

## What agent-os actually installs

- `.agent-os/prompts/tasks/` and `.agent-os/prompts/errors/` -- every request and every mistake captured as a small Markdown file with **frontmatter**, so the agent can scan dozens of them in one pass and jump to the relevant one. Completed tasks archive to `.agent-os/prompts/tasks/completed/`.
- `.agent-os/docs/` -- the source-of-truth skeleton you fill from a first full scan.
- Three skills -- `task-scan` (find related prior work), `error-check` (avoid repeating mistakes), `error-log` (the agent records its own errors).
- `.agent-os/scripts/check-prompts.sh` + `.agent-os/scripts/hooks/pre-commit` -- an opt-in **forced-sync** hook: it blocks a commit when prompt docs lack frontmatter, and warns when code changed without a docs update.
- A protocol section appended to the project's `CLAUDE.md`.

## Design principles

1. **Frontmatter is the index.** Routing on a handful of structured fields (`tags`, `area`, `files`, `summary`) is what makes "find the relevant context" cheap. Prose alone is not scannable.
2. **Forced sync beats good intentions.** Stale docs kill agent accuracy faster than model limits do. A doc that is wrong is worse than no doc. The pre-commit hook turns "please keep docs in sync" into a mechanism.
3. **The agent logs its own mistakes.** Errors are not noise to hide; they are the most valuable structured pattern for the next task. `error-check` reads them before work; `error-log` writes them after a slip.
4. **Verified facts only.** Documentation records what was confirmed in the code, never what was inferred from an import line. (This rule exists because the first build of this very system contradicted itself by assuming where a class lived -- exactly the failure the rule prevents.)
5. **Everything is maintainable, including the skills.** Skills are not frozen. When a path or schema drifts, the skill that references it is fixed in the same change. Skills carry self-maintenance notes for this reason.

## The work protocol (what changes day to day)

For every non-trivial request the agent runs: **task-scan -> read docs -> error-check -> execute -> error-log -> sync .agent-os/docs/skills -> close the task**. The cost is small (a few frontmatter scans); the payoff, *when the loop is actually followed*, is that intent stops leaking and the system can get *more* accurate over time instead of rotting. agent-os is a discipline scaffold, not an enforced pipeline: it makes the right habit cheap and visible, but nothing forces the loop on a given turn -- that is the human-in-the-loop's job (see the [Operating Guide](GUIDE.md)).

## Scaling: keeping memory cheap

Task and error docs accumulate forever, so naive scanning becomes O(N) in tokens and can burn a whole cycle. agent-os keeps it bounded with three moves:

1. **Index, don't glob.** `.agent-os/prompts/index.jsonl` is a generated catalog -- one compact line per task/error (id, status, area, tags, summary, path, plus the eviction signals `refs` and `pin`). Skills scan that single file; bodies load only on a strong match. Scanning cost drops from O(N files) to O(1 file).

2. **Compact by coldness, not by age.** This is the subtle part. Old does not mean cold. A finished doc is archived only if it is *also* unreferenced (`refs == 0`, nobody links to it), unpinned, and not recently updated. A doc that is heavily referenced or frequently edited stays hot no matter how old; an open error or active task is never a candidate. Age is the last gate, not the only one. This mirrors cache eviction (LRU/LFU + a reference graph), not a TTL.

3. **Compress semantically, store cheaply.** Archiving a cold doc keeps its summary line in `.agent-os/prompts/archive/*.jsonl` and removes the `.md`; the full text survives in git history (`git show`), so git is the free cold store. The highest-value compression is the *rollup*: N similar error logs collapse into one rule in `.agent-os/docs/` (known-risks) -- storage shrinks and the source of truth gets stronger at the same time.

**When does compaction trigger?** Mechanically and observably: `agent-os-health.sh` (run manually and by the pre-commit hook) and a SessionStart nudge report the active index size and the cold-candidate count, and warn when either crosses a threshold. Nothing is ever deleted automatically -- you are told to run `/agent-os:archive`, which previews before it applies.

The thresholds are derived, not magic numbers:

- The real cost is the tokens spent when a routing skill scans the index. One index line is ~335 bytes ~= **~100 tokens** (measured, with a CJK summary; ASCII is smaller). So a worst-case full-index read costs `entries x ~100` tokens.
- Budget that worst-case read at **~10% of the context window**. Then:

  ```
  MAX_ACTIVE (default) = CONTEXT_TOKENS / 1000        # = CONTEXT * 0.10 / 100tok-per-line
  COMPACT_NUDGE (default) = MAX_ACTIVE / 4            # a batch worth one compaction pass
  ARCHIVE_AGE_DAYS (default) = 90                     # convention (~1 quarter "stale"); the weakest signal
  ```

  | Context window | 10% budget | default MAX_ACTIVE | default NUDGE |
  |---|---|---|---|
  | 200k | ~20k tok | 200 | 50 |
  | 1M | ~100k tok | 1000 | 250 |

- Only `MAX_ACTIVE` is principled (token budget / line cost); `NUDGE` and `AGE_DAYS` are convention. All are env-overridable: `AGENT_OS_CONTEXT_TOKENS`, `AGENT_OS_MAX_ACTIVE`, `AGENT_OS_COMPACT_NUDGE`, `AGENT_OS_ARCHIVE_AGE_DAYS`. Set `AGENT_OS_CONTEXT_TOKENS` to your model's window and the rest scale with it.

## Why it generalizes

Nothing here is tied to a language or framework. Any project that is large enough to lose context, or old enough to have accumulated traps, benefits from a single source of truth, a scannable task/error memory, and a forced-sync mechanism. `/agent-os:init` lays down the structure; you supply the project-specific truth.

## Credit

The four-layer framing and the "structured procedural knowledge over raw history" insight come from Anthropic's writing on building skills for AI data analysis. agent-os is a lightweight, code-focused adaptation of that idea.
