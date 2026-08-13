# agent-os

**Languages:** English | [한국어](README.ko.md) | [日本語](README.ja.md)

An **agent operating system** for legacy / high-ambiguity codebases — a Claude Code plugin.

On a big or old codebase, an AI agent's intent leaks: it assumes instead of verifying, repeats past mistakes, and lets docs rot. agent-os fixes the *structure*, not the model: it gives a project a single source of truth, a scannable task/error memory, self-maintaining skills, and a forced-sync hook — so that, *when the loop is followed*, the agent can get **more** accurate over time instead of drifting. It is a discipline scaffold the human keeps in the loop, not an automatic guarantee.

> **How to use it:** the **[Operating Guide](docs/GUIDE.md)** — the human-in-the-loop loop (setup -> task -> review -> execute -> self-improve -> repeat). Start here.
>
> The full rationale is in **[docs/CONCEPT.md](docs/CONCEPT.md)** — read it to understand and adopt the idea.

## Core idea (summary)

The idea agent-os borrows (from Anthropic's writing on building *skills*): feeding a model more raw history barely moves accuracy; what moves it is **structured procedural knowledge** (a *skill*). agent-os is a small — and so far unmeasured — application of that idea, shaped as a four-layer model. You measure whether it actually helps with the Validation layer.

- **Foundation** (`CLAUDE.md`): the work protocol every request follows (the router).
- **Source of Truth** (`.agent-os/docs/`): a verified description of the system, written from a real scan. The code is ground truth; when docs disagree, trust the code and fix the docs.
- **Skills**: three router skills — `task-scan` (find related prior work), `error-check` (avoid repeating mistakes), `error-log` (the agent records its own mistakes).
- **Validation** (`.agent-os/prompts/eval/`): a known-answer eval set that checks, with numbers, whether a change is an improvement — and whether a rule still earns its place.

## What you get

- **Ranking, not scanning.** `rank.sh` scores every index entry and returns the best few; the skills open the top 3. Recall was never the problem — *precision* was. A flat grep finds the right document and buries it among dozens; the ranker puts it first.
- **The strongest signal is the file you are about to touch.** Pass the paths to `-f` and a past error about one of them surfaces even with zero keyword matches.
- **Ask in any language.** `.agent-os/vocab.txt` maps a concept to its spellings, so a Japanese question reaches a Korean-written error. Documents are never retagged — only the query is expanded.
- **Recurrence is counted, not narrated.** The same root cause bumps a counter instead of opening a second document. At three repeats, editing the document stops being an acceptable response: promote the lesson or build a mechanical gate.
- **Decision records** (`.agent-os/docs/adr/`): what was *rejected* and *what would reopen it*. Indexed, so a re-proposal hits the rejection before the work starts.
- **Skills** (auto-routing): `task-scan`, `error-check`, `error-log`
- **Command**: `/agent-os:init [--no-eval]` — scaffolds everything under **`.agent-os/`** plus a root `CLAUDE.md` protocol section, keeping the project root clean (never overwrites existing files). `--update` refreshes only the protocol block in an existing `CLAUDE.md`.
- **Forced sync** (opt-in): a `pre-commit` hook that lints the frontmatter of the documents you are committing — enum values, dates, unreplaced placeholders — and warns when code changes without a `.agent-os/docs/` update. Only what you touch is held strictly, so an existing project is not blocked by its own history.
- **Bounded memory**: a generated `.agent-os/prompts/index.jsonl` + `/agent-os:archive`, which archives only *cold* docs — finished, unreferenced, unpinned, and old (not by age alone); full text stays in git. Promote the lesson to known-risks *first* — that is what makes archiving safe.
- **A health check for what has gone quiet**: an index older than the docs, open tasks nobody has touched in 30 days, over-pinning, repeats that never became rules, an empty eval set, a protocol that has outgrown its budget. Read-only; it tells you, it does not act.

## Install

```
/plugin marketplace add /absolute/path/to/agent-os-plugin
/plugin install agent-os@agent-os
```

Or load directly for development (session only):

```
claude --plugin-dir /absolute/path/to/agent-os-plugin
```

Once published to GitHub: `/plugin marketplace add <owner>/<repo>`.

## Use

```
/agent-os:init             # scaffold the structure (includes the Validation eval set)
/agent-os:init --no-eval   # skip the evaluation set (Validation layer)
```

After scaffolding:

1. `git config core.hooksPath .agent-os/scripts/hooks` — enable the forced-sync hook
2. Fill `.agent-os/docs/` with the project's source of truth from a first full scan (the scaffold only writes the index skeleton)
3. Fill `.agent-os/prompts/eval/eval-set.md` — five rows, from what has actually bitten this project. It is the only instrument that can tell you later whether a rule still earns its place; without it, adding *and* removing rules are both guesses
4. Work is sized, not marched through: **trivial** goes straight to the answer, **local** needs only `error-check`, **broad** takes the full loop

## Day to day

**There is no command for the daily loop — you just talk.** `init` and `archive` are the
only two slash commands. Everything else runs on the three skills, whose descriptions *are*
their trigger conditions, so the agent invokes them from a plain sentence.

| Say something like | What runs | Why it fires |
|---|---|---|
| "write this up as a task" | `task-scan` | it covers *creating* task docs, not just finding them |
| "have we done this before?" | `task-scan` | matches related prior work first, so you don't redo it |
| "log that mistake" | `error-log` | also fires on its own when the agent judges it slipped |
| "have I hit this before?" | `error-check` | and automatically before editing or debugging |

**You never hand-write frontmatter.** The skills number the file, copy `_TEMPLATE.md`, and
fill `status`/dates. A new task lands as `.agent-os/prompts/tasks/NN_slug.md`,
`status: planned`.

A broad change, end to end:

```
"add SSO to the login flow"
   -> task-scan finds prior auth work and the docs that own it; error-check
      surfaces traps recorded against the files you are about to touch
"write it up as a task first"        -> NN_sso_login.md, status: planned
        ... you build, the agent records what bit it as it goes ...
"close it out"                       -> status: completed, moved to completed/,
                                        docs updated in the same change
```

The pre-commit hook checks the mechanical part. `agent-os-health.sh` tells you what has gone
quiet. Neither decides anything for you.

**What stays yours.** The skills route and format; they do not judge. Filling `.agent-os/docs/`
from a real scan, deciding which lesson becomes a rule in `07_known-risks.md`, calling a change
broad, and approving that it is done — all still yours. This is a scaffold that keeps you in
the loop, not an autopilot.

## Tuning

Thresholds are derived from your context window, not hardcoded. Set `AGENT_OS_CONTEXT_TOKENS` to your model's window; `AGENT_OS_MAX_ACTIVE` (default `CONTEXT_TOKENS/1000`) and `AGENT_OS_COMPACT_NUDGE` (default `MAX/4`) scale from it. See [docs/CONCEPT.md](docs/CONCEPT.md#scaling-keeping-memory-cheap) for the math.

The text agent-os injects into every session is capped too — 3000 characters for the protocol block, 2000 per skill body. Over budget the rule is *replace, not append*: rationale belongs in `.agent-os/docs/`, not in a prompt that is read every time.

## Structure

```
agent-os/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/{task-scan,error-check,error-log}/SKILL.md
├── commands/{init.md, archive.md}
├── scripts/
│   ├── init.sh              # scaffold, or --update an existing CLAUDE.md
│   ├── reindex.sh rank.sh   # build the index; rank against it
│   ├── check-prompts.sh     # frontmatter lint (keys, enums, dates, placeholders)
│   ├── tags-gap.sh          # which docs are unfindable because tags are empty
│   ├── agent-os-compact.sh  # cold-doc archival
│   ├── agent-os-health.sh   # what has gone quiet
│   ├── bare-test.md         # is this harness still earning its place?
│   └── pre-commit
├── templates/            # scaffolded into the target project (incl. vocab.txt, ADR, known-risks)
├── docs/CONCEPT.md       # the idea
└── README*.md
```

Every script is a single `awk` pass over the index rather than a shell loop. That is not
cosmetic: on Windows, where process creation is expensive, the loop version took **43 minutes**
to index a 260-document repo and **6 minutes** to preview a compaction. Tools that slow cannot
be run, and a check nobody runs is a check that does not exist.

## Conventions

Skills, command, templates, and scripts are **English-only** (they are prompt/operational material). Only this README is localized. Documentation records **verified facts only**; secret values are never copied into docs/prompts.

## License

MIT — see [LICENSE](LICENSE).
