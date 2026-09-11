# agent-os — Operating Guide

**Languages:** English | [한국어](GUIDE.ko.md) | [日本語](GUIDE.ja.md)

Set it up once. After that, talk normally and let the repository memory grow instead of rotting.
This guide is *what to do*; [CONCEPT.md](CONCEPT.md) is *why it is built this way*.

---

## 1. Pick the host adapter

The memory model is the same everywhere; only the entry point changes.

| Host | Install / entry | Project guidance | Mode |
|---|---|---|---|
| Claude Code | Claude plugin, `/agent-os:init` | root `CLAUDE.md` | full local mode |
| Codex | OpenAI plugin, `$agent-os-init` / `$agent-os` | root `AGENTS.md` | full local/Codex mode |
| ChatGPT | OpenAI plugin Skills, e.g. `@agent-os` | Skills are the primary entry; do not assume repo `AGENTS.md` is auto-loaded | capability-dependent |

The ordinary ChatGPT GitHub app is read-only. In that environment agent-os can still search prior
tasks/errors/known-risks and prepare exact changes, but it must not claim a task was created,
closed, committed or pushed. If the active surface exposes repository writes or a full work/Codex
environment, the same Skills can operate in writable mode.

---

## 2. Setup once per project

Claude Code:

```text
/plugin marketplace add <owner>/<repo>
/plugin install agent-os@agent-os
/agent-os:init
```

Codex / ChatGPT: install **agent-os** from the OpenAI plugin marketplace/source represented by
`.agents/plugins/marketplace.json` and `.codex-plugin/plugin.json`, then invoke
`$agent-os-init` (Codex) or `@agent-os-init` (ChatGPT).

Direct installer, valid in any shell-capable host:

```sh
bash <plugin>/scripts/init.sh [--no-eval] /path/to/project
```

Already scaffolded:

```sh
bash <plugin>/scripts/init.sh --update /path/to/project
```

`init.sh` creates `.agent-os/` plus root `CLAUDE.md` and `AGENTS.md` from one canonical protocol.
`--update` changes only the marked agent-os block and preserves text outside the markers. A
pre-0.8 Claude-only project gets the missing `AGENTS.md`; malformed markers abort before either
host file is partially rewritten.

Then:

1. **Build the source of truth.** Scan the real repo and fill `.agent-os/docs/`. Verify it once
   yourself; downstream work trusts it.
2. **Fill the eval set** from failures that actually happened in this project.
3. **Turn on the hook**: `git config core.hooksPath .agent-os/scripts/hooks`.
4. **Run portability** on a new machine: `sh .agent-os/scripts/portability-test.sh`.
5. **Seed vocab** with project/domain aliases so cross-language retrieval works.

---

## 3. A normal broad task

**You:** “the detail page shows a different buy/sell status than the list page — make them match.”

Before editing, agent-os reads `07_known-risks.md`, finds related tasks/ADRs, and checks relevant
past errors. In shell mode it uses:

```sh
sh .agent-os/scripts/rank.sh -q "<request words>" -f "<paths you will touch>" -n 8
```

Open at most the top three records. Without shell, use repository search over task/error/ADR
frontmatter and prefer file-path/root-cause hits.

**You:** “write it up as a task first.”

A writable host creates `.agent-os/prompts/tasks/NN_slug.md`, `status: planned`, from the template.
A read-only host returns the exact proposed file/frontmatter and says it was not written.

> **Gate 1 — read Scope / Plan.** Correct the frame before implementation.

**You:** “go ahead.”

The agent implements, logs verified decisions/traps, and checks past errors again before risky
steps.

> **Gate 2 — read Verification / diff.** Irreversible or outward-facing actions still need human
> approval.

**You:** “close it out.”

Writable mode updates docs, records mistakes/decisions if needed, sets `status: completed`, moves
the task to `completed/`, and lets the pre-commit gate lint the mechanical fields. Read-only mode
returns the same closeout checklist without pretending it applied it.

---

## 4. What triggers what

| Say something like | Skill / command |
|---|---|
| “use agent-os for this repo” | `agent-os` |
| “write this up as a task” / “did we do this before?” | `task-scan` |
| “have I hit this mistake before?” | `error-check` |
| “log that mistake” | `error-log` |
| “initialize/update agent-os” | `agent-os-init` (Claude compatibility: `/agent-os:init`) |
| “clean up cold memory” | `agent-os-archive` (Claude compatibility: `/agent-os:archive`) |

Work is sized, not marched through. Trivial work is direct; local work normally needs only
`error-check`; broad work runs the full memory lookup.

---

## 5. Capability modes

**Full mode** — shell + writable files. Use scripts, task/error lifecycle, hooks and verification.

**Repository mode** — repository read/write tools, no shell. Search and edit the same files through
repository tools; do not invent results from scripts you could not run.

**Read-only mode** — repository search/read only. Retrieve bounded context and prepare exact edits.
Never say a file/status/commit/push changed.

This capability-first rule is deliberate: product surfaces change more often than the memory
format does.

---

## 6. Memory maintenance

`agent-os-health.sh` is read-only. Pay attention to:

| Warning | Response |
|---|---|
| docs newer than index | run `reindex.sh` |
| cold docs / index over budget | preview `agent-os-archive`; promote durable lessons first |
| recurrence 3+ not promoted | known-risk or mechanical gate |
| stale open tasks | close or document why blocked |
| over-pinning | unpin items that are important but not permanently load-bearing |
| empty eval set | add real known-answer cases |
| prompt budget exceeded | replace rules; do not append forever |

Age alone never makes a document cold. Full text remains in git history after archival.

---

## 7. Distribution verification

Plugin maintainers run:

```sh
sh scripts/host-adapter-test.sh
```

The fixture checks:

- canonical protocol == Claude template == AGENTS template;
- lab root host guidance does not drift;
- Claude/OpenAI plugin name and version match;
- convention hook is not redundantly declared;
- shared Skill metadata exists;
- fresh init creates both host files;
- update preserves text outside markers;
- Claude-only installs gain `AGENTS.md`;
- malformed markers fail closed before partial writes.

`portability-test.sh` remains the machine-level gate for shell/awk/locale behavior.

---

## 8. Cheatsheet

| Thing | What it is |
|---|---|
| `agent-os` | shared protocol/router skill |
| `agent-os-init` | cross-host initialization/update skill |
| `agent-os-archive` | cross-host cold-memory maintenance |
| `task-scan` | related prior work + task lifecycle |
| `error-check` | prior mistakes before work |
| `error-log` | structured mistake/recurrence recording |
| `CLAUDE.md` | Claude Code view of the protocol |
| `AGENTS.md` | Codex view of the same protocol |
| `.agent-os/docs/` | verified source of truth |
| `07_known-risks.md` | durable traps as rules |
| `.agent-os/docs/adr/` | rejected alternatives + revisit conditions |
| `.agent-os/vocab.txt` | cross-language/domain aliases |
| `.agent-os/prompts/index.jsonl` | generated retrieval catalog |
| `rank.sh` | bounded relevance retrieval |
| `agent-os-health.sh` | read-only memory health |
| `host-adapter-test.sh` | distribution/host adapter gate |
| `portability-test.sh` | machine portability gate |

See [CONCEPT.md](CONCEPT.md) for the design rationale.
