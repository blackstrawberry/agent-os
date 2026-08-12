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

- **Foundation** -- one always-loaded guide (`CLAUDE.md`). It does *not* prescribe a fixed order of steps; it states what you must **know** before broad work (related prior work, rejected decisions, this area's source of truth, its past traps) and leaves the route to judgement, keeping hard gates only where a machine can check them. It also sizes the work: trivial answers directly, local needs one check, broad takes the loop. An ordered march sends every medium job through the full course, which is how a protocol earns a reputation for being slow and then gets ignored.
- **Source of Truth** -- `.agent-os/docs/` holds the project's architecture, core logic, conventions, and known risks. It is written from a real scan of the code, not from assumption, and it is what the agent consults first to orient itself. The code is still ground truth: when code and docs disagree, you trust the code and **fix the docs**.
- **Skills** -- small procedures the agent invokes. Two kinds, mirroring Anthropic's split: *router* skills that point to the ~right slice of context (a "front desk"), and *cookbook* skills that run a vetted workflow. agent-os ships three routers: `task-scan`, `error-check`, `error-log`.
- **Validation** -- an offline eval set (`.agent-os/prompts/eval/`) of questions with known answers, drawn from the project's real traps. It lets you prove that a .agent-os/docs/skill change improved things instead of guessing.

## What agent-os actually installs

- `.agent-os/prompts/tasks/` and `.agent-os/prompts/errors/` -- every request and every mistake captured as a small Markdown file with **frontmatter**, so the agent can scan dozens of them in one pass and jump to the relevant one. Completed tasks archive to `.agent-os/prompts/tasks/completed/`.
- `.agent-os/docs/` -- the source-of-truth skeleton you fill from a first full scan, including `07_known-risks.md` (the traps, as rules) and `adr/` (**decisions: what was rejected, and what would reopen it**).
- `.agent-os/vocab.txt` -- a per-project map from a concept to its spellings across languages, so a question asked in one reaches documents written in another.
- Three skills -- `task-scan` (find related prior work and rejected decisions), `error-check` (avoid repeating mistakes), `error-log` (the agent records its own errors).
- `.agent-os/scripts/` -- `reindex.sh` builds the index; `rank.sh` scores against it; `check-prompts.sh` lints frontmatter; `tags-gap.sh` finds documents nothing can locate; `agent-os-compact.sh` archives cold docs; `agent-os-health.sh` reports what has gone quiet; `bare-test.md` is the procedure for asking whether a rule still earns its place.
- `.agent-os/scripts/hooks/pre-commit` -- an opt-in **forced-sync** hook: it lints the frontmatter of the documents in *this* commit (enum values, dates, unreplaced placeholders) and warns when code changed without a docs update. Only what you touch is held strictly, so an existing project is not held hostage by its own history.
- A protocol section appended to the project's `CLAUDE.md`, under a size budget.

## Design principles

1. **Frontmatter is the index.** Routing on a handful of structured fields (`tags`, `area`, `files`, `summary`) is what makes "find the relevant context" cheap. Prose alone is not scannable.
1b. **The problem was never recall -- it was ranking.** Measured on a 260-document repo with ten questions written from each target's symptoms: a flat grep found the right document 9 times out of 10, and put it in the top three **once**. It was buried among 23 to 70 matches, and picking from that list by hand is the work the scan was supposed to save. Weighted ranking put it in the top three 9 times out of 10. Searching wider was never the fix; ordering was.
1c. **A rule with no expiry is a rule that only accumulates.** Every rule was added for a reason and none carries a date. Some compensate for a model weakness that a newer model no longer has, and dead weight in a prompt is not free -- it costs context and dilutes what still matters. So removing a rule needs evidence exactly as much as adding one did, which is what the eval set and `bare-test.md` are for. Absent that, the honest move is to keep it.
2. **Forced sync beats good intentions.** Stale docs kill agent accuracy faster than model limits do. A doc that is wrong is worse than no doc. The pre-commit hook turns "please keep docs in sync" into a mechanism.
3. **The agent logs its own mistakes.** Errors are not noise to hide; they are the most valuable structured pattern for the next task. `error-check` reads them before work; `error-log` writes them after a slip.
4. **Verified facts only.** Documentation records what was confirmed in the code, never what was inferred from an import line. (This rule exists because the first build of this very system contradicted itself by assuming where a class lived -- exactly the failure the rule prevents.)
5. **Everything is maintainable, including the skills.** Skills are not frozen. When a path or schema drifts, the skill that references it is fixed in the same change. Skills carry self-maintenance notes for this reason.

## The work protocol (what changes day to day)

Broad work: the agent finds related prior work and rejected decisions (by *ranking* the index, not scanning it), reads the source of truth, checks past errors, executes, records what it learned, syncs docs, and closes the task. Local work skips to the error check. Trivial work is just answered. The cost is small; the payoff, *when the loop is actually followed*, is that intent stops leaking and the system can get *more* accurate over time instead of rotting. agent-os is a discipline scaffold, not an enforced pipeline: it makes the right habit cheap and visible, but nothing forces the loop on a given turn -- that is the human-in-the-loop's job (see the [Operating Guide](GUIDE.md)).

Two things the loop counts rather than narrates. **Recurrence**: the same root cause bumps a counter on the existing error document instead of opening a second one -- two files for one trap make a three-time trap look like three one-offs. At three repeats, editing the document stops being an acceptable response; the lesson gets promoted or a mechanical gate gets built, because three repeats are evidence that prose does not prevent it. **Rejection**: a decision record captures what was turned down and what would reopen it, and is indexed, so a re-proposal meets the rejection before the work starts rather than two recurrences later.

## Scaling: keeping memory cheap

Task and error docs accumulate forever, so naive scanning becomes O(N) in tokens and can burn a whole cycle. agent-os keeps it bounded with three moves:

1. **Index, don't glob.** `.agent-os/prompts/index.jsonl` is a generated catalog -- one compact line per task, error and decision (id, status, area, tags, summary, path, the eviction signals `refs` and `pin`, and the weighting signals `sev`, `rec`, `files`, `kw`, `rc`). Scanning cost drops from O(N files) to O(1 file).

1b. **Rank the index, don't read it.** O(1 file) is still the wrong unit once that file is 136KB: telling a skill to "grep for error lines" pulls *every* error into context. `rank.sh` scores each line and returns the best few; the skills open three. Because a shell process does the reading, the file's size stops being a token cost -- which is why the summaries are **not** truncated. That was measured: summary is only 39% of the index, so capping it damages half the documents to save a fifth of the bytes, and the added signal fields cost more than the cap saves. The strongest single signal is not a keyword at all but `-f`: a document naming a file you are about to touch surfaces with zero keyword matches.

1c. **The query is expanded, never the documents.** Teams write in more than one language, and the same concept scatters across all of them. `vocab.txt` maps a concept to its spellings and expands the *query*; not one document is retagged, so the cost of adding a line is zero. Measured: Japanese questions against Korean-written errors went from finding **nothing at all** -- Japanese has no spaces, so splitting a query on whitespace yields one token that matches nothing -- to 5 of 5.

2. **Compact by coldness, not by age.** This is the subtle part. Old does not mean cold. A finished doc is archived only if it is *also* unreferenced (`refs == 0`, nobody links to it), unpinned, and not recently updated. A doc that is heavily referenced or frequently edited stays hot no matter how old; an open error or active task is never a candidate. Age is the last gate, not the only one. This mirrors cache eviction (LRU/LFU + a reference graph), not a TTL.

3. **Compress semantically, store cheaply.** Archiving a cold doc keeps its summary line in `.agent-os/prompts/archive/*.jsonl` and removes the `.md`; the full text survives in git history (`git show`), so git is the free cold store. The highest-value compression is the *rollup*: N similar error logs collapse into one rule in `.agent-os/docs/` (known-risks) -- storage shrinks and the source of truth gets stronger at the same time.

**When does compaction trigger?** Mechanically and observably: `agent-os-health.sh` and a SessionStart nudge report the active index size and the cold-candidate count, and warn when either crosses a threshold. Nothing is ever deleted automatically -- you are told to run `/agent-os:archive`, which previews before it applies.

Health also reports the failures that are otherwise **silent**: an index older than the documents it catalogues (so every scan reads a stale catalogue and nothing says so), open tasks nobody has touched in a month, over-pinning (`pin` means load-bearing forever, not important -- pin most of the repo and cold detection stops working entirely), repeats that never became rules, an empty eval set, and a protocol block that has outgrown its budget. It is read-only by design: a SessionStart hook that edits files makes session start unpredictable.

**Speed is a correctness property here.** Every one of these scripts is a single `awk` pass rather than a shell loop, and that is not style. The loop version spawned a subprocess per field; on Windows, where process creation costs tens of milliseconds, indexing a 260-document repo took **43 minutes** and previewing a compaction took **6 minutes**. Nobody runs those, so the index goes stale and compaction never happens -- and the tool meant to *report* that compaction had died was itself calling the six-minute one. A check too slow to run is a check that does not exist.

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
