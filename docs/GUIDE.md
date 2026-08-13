# agent-os — Operating Guide

**Languages:** English | [한국어](GUIDE.ko.md) | [日本語](GUIDE.ja.md)

Set it up once. After that you talk normally, and the project's knowledge grows instead of
rotting. This guide is *what to do*; [CONCEPT.md](CONCEPT.md) is *why it is built this way*.

---

## 1. Setup (once per project)

```
/plugin marketplace add /path/to/agent-os-plugin
/plugin install agent-os@agent-os
/agent-os:init                 # --no-eval skips the eval set
```

Already scaffolded? `sh <plugin>/scripts/init.sh --update .` refreshes only the protocol block
in your `CLAUDE.md` and leaves everything outside the markers alone.

Then, in order of how much damage skipping them does:

1. **Build the source of truth.** Have the agent scan the whole repo and fill
   `.agent-os/docs/01..07` (overview, architecture, directory map, core, data layer,
   conventions, known risks). **Read it once yourself** — everything downstream trusts these
   files, so a wrong fact here quietly poisons every later task. Verified facts only.
2. **Fill the eval set** — five rows in `.agent-os/prompts/eval/eval-set.md`, from what has
   actually bitten *this* project. Across 19 installs, 17 never did. It is the only instrument
   that can later tell you whether a rule still earns its place.
3. **Turn on the hook**: `git config core.hooksPath .agent-os/scripts/hooks`, then
   `sh .agent-os/scripts/portability-test.sh` to confirm it can run — git refuses a hook
   without the exec bit and says so only in a hint that scrolls past.
4. **Trim `.agent-os/vocab.txt`** to the words this project uses. This is what lets a question
   in one language reach a document written in another.

---

## 2. A day with agent-os

Nothing below is a command. You talk; the skills fire on what you said.

**You:** *"the detail page shows a different buy/sell status than the list page — make them match"*

Before touching anything the agent ranks what the project already knows: `task-scan` opens the
top 3 index hits, `error-check` surfaces traps recorded against the files it is about to edit,
and it reads `.agent-os/docs/`, `07_known-risks.md` first. A decision record outranks all of
it — someone already rejected an option here, and its *Revisit when* says if that still holds.

**You:** *"write it up as a task first"*

```
.agent-os/prompts/tasks/04_buysell-detail-status-mismatch.md
  status: planned      Request / Scope · non-scope / Plan filled in
```

You never type frontmatter: the skill numbers the file, copies the template, sets dates and
`status`, and writes `tags` — untagged means the ranker cannot find it later.

> ### ▸ Gate 1 — you read the Scope and the Plan
> The cheapest place to fix a misunderstanding. Correct the scope, reject a wrong assumption,
> or say go. Execution on a wrong frame is the expensive mistake.

**You:** *"go ahead"*

The agent implements, recording decisions and touched files in the **Work log**, re-running
`error-check` before risky steps (shared core, DB, migrations), and verifying its own work.

> ### ▸ Gate 2 — you read the Verification section and the diff
> Accept, or send it back. Anything irreversible or outward-facing — deploys, deletions,
> credentials, external calls — stops here and asks you, every time.

**You:** *"close it out"*

The agent syncs what it learned before closing: `.agent-os/docs/` for changed behaviour, an
`error-log` if it slipped (searching first, so a repeat bumps an existing document's
`recurrence` rather than opening a second one), a decision record if a real alternative was
dropped and reversing would be expensive. Then `status: completed`, the file moves to
`completed/`, and the pre-commit hook lints what you commit.

**The request did not just get done — the source of truth grew.** The next task starts from
more than this one did.

---

## 3. What you say, and what runs

| Say something like | What runs | Why it fires |
|---|---|---|
| "write this up as a task" | `task-scan` | it covers *creating* task docs, not only finding them |
| "have we done this before?" | `task-scan` | related prior work first, so you don't redo it |
| "log that mistake" | `error-log` | also fires on its own when the agent judges it slipped |
| "have I hit this before?" | `error-check` | and automatically before editing or debugging |
| "clean up the memory" | `/agent-os:archive` | previews cold docs, archives on your OK |

Work is **sized, not marched through**. Trivial (a commit, one command, a one-line answer) is
answered directly. Local (one file, a clear bug) needs only `error-check`. Only broad work —
many files, a design change, a new feature — runs the full day above.

Searching is ranked, never grepped:

```sh
sh .agent-os/scripts/rank.sh -q "<words>" -f "<paths you will touch>" -n 8
```

`-f` is the strongest signal — a past error about a file you are about to touch surfaces with
zero keyword overlap. Ask in any language. A search that *should* have hit and didn't means a
missing line in `vocab.txt`; add it there rather than retagging old documents.

---

## 4. Where you stay in the loop

The two gates above, plus three things the agent never decides alone: **irreversible or
outward-facing actions** (deploys, deletions, credentials, external calls), **security
decisions** (credential rotation, exposed tools), and **what leaves the active set** when
archiving. Signing off the source of truth at setup is the fourth, and the one everything
else rests on. The rest is the agent's to run.

---

## 5. When a warning appears

`agent-os-health.sh` is what breaks the silence. It is **read-only** — it tells you, it never
acts. Run it when you feel like it; it costs a second.

| It says | Do this |
|---|---|
| docs newer than the index | `sh .agent-os/scripts/reindex.sh` — every scan is reading a stale catalog |
| index over budget / cold docs | `/agent-os:archive` — previews first. **Promote the lesson to known-risks before archiving**; archive an unpromoted lesson and it is gone |
| errors at `recurrence` 3+ not in known-risks | Three repeats prove prose does not prevent this. Promote it, or open a task for a mechanical gate — a hook, a lint rule, a test |
| error docs but no `07_known-risks.md` | Nothing has become a rule yet. The errors are memory; the rules are what stop repeats |
| open tasks untouched 30+ days | Close them, or write down why they are blocked |
| pinned over the threshold | `pin` means load-bearing forever, not important. Over-pin and cold detection stops working at all |
| eval set still the shipped file | Fill the five rows. Without it, adding *and* removing rules are both guesses |
| injected text over budget | Replace, never append — rationale belongs in `.agent-os/docs/`, not in a prompt read every session |

Two more, on your own schedule. **`tags-gap.sh`** lists documents nothing can find because
their tags are empty; it only reports, since a wrong tag in the highest-weighted field is
worse than a gap. **`bare-test.md`**, once per model generation, runs the eval set with the
protocol block commented out and then with it on. That comparison is the only thing that ever
justifies *deleting* a rule — and no difference is the finding, not a failed experiment.
Without it, rules only ever accumulate.

---

## 6. Cheatsheet

| Thing | What it is |
|---|---|
| `/agent-os:init [--no-eval]` | scaffold the structure into a project |
| `init.sh --update` | refresh only the protocol block in an existing `CLAUDE.md` |
| `/agent-os:archive [--apply]` | archive cold docs (preview, then apply) |
| skill `task-scan` | find related prior work + rejected decisions; also writes new task docs |
| skill `error-check` | check past mistakes before working |
| skill `error-log` | the agent records its own mistakes (search first, count recurrences) |
| `CLAUDE.md` | the always-loaded work protocol (budget: 3000 chars) |
| `.agent-os/docs/` | source of truth (you fill it from a real scan) |
| `.agent-os/docs/07_known-risks.md` | the traps, as rules. Read before working |
| `.agent-os/docs/adr/` | decisions: what was rejected, what would reopen it |
| `.agent-os/vocab.txt` | concept → its spellings across languages |
| `.agent-os/prompts/tasks/` `errors/` | the working memory (frontmatter docs) |
| `.agent-os/prompts/eval/eval-set.md` | five known-answer questions; the only rule-lifetime instrument |
| `.agent-os/prompts/index.jsonl` | generated catalog the ranker reads |
| `rank.sh -q "..." -f "paths"` | **the way to find things.** Top few, not everything |
| `reindex.sh` | rebuild the index |
| `check-prompts.sh [--report]` | frontmatter lint; `--report` never fails |
| `tags-gap.sh` | documents nothing can find (tags empty) |
| `agent-os-health.sh [--oneline]` | what has gone quiet. Read-only |
| `portability-test.sh [-v]` | same answer on every machine? Run it on a new one |
| `bare-test.md` | is this harness still earning its place? |
| `git config core.hooksPath .agent-os/scripts/hooks` | turn on forced sync |

**On a new machine, run `portability-test.sh` first.** Two clone-local things no checkout
carries: `core.hooksPath` is unset, so the commit gate is off, and git refuses a hook that lost
its exec bit — on macOS and Linux, silently. It also checks where implementations disagree:
macOS `awk` counts `length()` in bytes where GNU `awk` counts characters, and glob order
follows `LC_COLLATE`, so an index built in two locales holds the same entries in a different
order. Every script pins `LC_ALL=C` for that reason; this test is what keeps it true.

See [CONCEPT.md](CONCEPT.md) for *why* it is built this way.
