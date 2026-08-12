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
- **Validation** (`.agent-os/prompts/eval/`): a known-answer eval set that checks, with numbers, whether a change is an improvement.

## What you get

- **Skills** (auto-routing): `task-scan`, `error-check`, `error-log`
- **Command**: `/agent-os:init [--no-eval]` — scaffolds everything under **`.agent-os/`** (prompts, docs, scripts, and the Validation eval set) plus a root `CLAUDE.md` protocol section, keeping the project root clean (never overwrites existing files); `--no-eval` skips the eval set
- **Forced sync** (opt-in): a `pre-commit` hook that blocks commits with missing frontmatter and warns when code changes without a `.agent-os/docs/` update
- **Bounded memory**: a generated `.agent-os/prompts/index.jsonl` (scan one file, not N) + `/agent-os:archive`, which archives only *cold* docs — finished, unreferenced, unpinned, and old (not by age alone); full text stays in git. A SessionStart hook nudges you to compact once memory grows past a threshold.

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
3. From then on, every request follows: `task-scan → read docs → error-check → execute → error-log → sync`

## Tuning

Thresholds are derived from your context window, not hardcoded. Set `AGENT_OS_CONTEXT_TOKENS` to your model's window; `AGENT_OS_MAX_ACTIVE` (default `CONTEXT_TOKENS/1000`) and `AGENT_OS_COMPACT_NUDGE` (default `MAX/4`) scale from it. See [docs/CONCEPT.md](docs/CONCEPT.md#scaling-keeping-memory-cheap) for the math.

## Structure

```
agent-os/
├── .claude-plugin/{plugin.json, marketplace.json}
├── skills/{task-scan,error-check,error-log}/SKILL.md
├── commands/init.md
├── scripts/{init.sh, check-prompts.sh, pre-commit}
├── templates/            # scaffolded into the target project
├── docs/CONCEPT.md       # the idea
└── README*.md
```

## Conventions

Skills, command, templates, and scripts are **English-only** (they are prompt/operational material). Only this README is localized. Documentation records **verified facts only**; secret values are never copied into docs/prompts.

## License

MIT — see [LICENSE](LICENSE).
